# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"
require "models/comment"

class ReverseUnorderedSelectsTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :posts, :comments

  setup do
    @original = ActiveRecord.reverse_unordered_selects
  end

  teardown do
    ActiveRecord.reverse_unordered_selects = @original
  end

  test "unordered relations are reversed" do
    ids = with_reversal(false) { Post.all.map(&:id) }

    assert_equal ids.reverse, with_reversal(true) { Post.all.map(&:id) }
  end

  test "ordered relations are left alone" do
    ids = with_reversal(false) { Post.order(:id).map(&:id) }

    assert_equal ids, with_reversal(true) { Post.order(:id).map(&:id) }
  end

  test "unordered pluck is reversed" do
    ids = with_reversal(false) { Post.pluck(:id) }

    assert_equal ids.reverse, with_reversal(true) { Post.pluck(:id) }
  end

  test "raw SQL is left alone" do
    ids = with_reversal(false) { Post.find_by_sql("SELECT * FROM posts").map(&:id) }

    assert_equal ids, with_reversal(true) { Post.find_by_sql("SELECT * FROM posts").map(&:id) }
  end

  test "unordered associations are reversed" do
    ids = with_reversal(false) { authors(:david).posts.reload.map(&:id) }

    assert_equal ids.reverse, with_reversal(true) { authors(:david).posts.reload.map(&:id) }
  end

  test "ordered associations are left alone" do
    ids = with_reversal(false) { authors(:david).posts_sorted_by_id.reload.map(&:id) }

    assert_equal ids, with_reversal(true) { authors(:david).posts_sorted_by_id.reload.map(&:id) }
  end

  test "preloaded associations are reversed consistently with lazily loaded ones" do
    with_reversal(true) do
      preloaded = Author.preload(:posts).find(authors(:david).id).posts.map(&:id)

      assert_equal authors(:david).posts.reload.map(&:id), preloaded
    end
  end

  test "eager loaded associations are reversed" do
    ids = with_reversal(false) { Author.eager_load(:posts).find(authors(:david).id).posts.map(&:id) }

    assert_equal ids.reverse, with_reversal(true) {
      Author.eager_load(:posts).find(authors(:david).id).posts.map(&:id)
    }
  end

  test "reversal is applied consistently when the query cache is enabled" do
    with_reversal(true) do
      uncached = Post.pluck(:id)

      Post.cache do
        assert_equal uncached, Post.pluck(:id)
        assert_equal uncached, Post.pluck(:id) # cache hit
      end
    end
  end

  # The association goes through StatementCache (a precompiled SQL string) while
  # the relation goes through Arel. Both compile to the same SQL and therefore
  # share a query cache entry, so they must agree on the row order whichever one
  # populates the cache first.
  test "an association and an equivalent relation agree inside a query cache block" do
    author = authors(:david)

    with_reversal(true) do
      Post.cache do
        assert_equal Post.where(author_id: author.id).map(&:id),
          author.posts.reload.map(&:id)
      end
    end

    with_reversal(true) do
      Post.cache do
        assert_equal author.posts.reload.map(&:id),
          Post.where(author_id: author.id).map(&:id)
      end
    end
  end

  # Raw SQL is never reversed, so it must not pick up (or hand out) a reversed
  # result through a query cache entry it shares with the generated query. The
  # raw string here is byte-identical to what Post.all compiles to.
  test "raw SQL is left alone even when it matches a generated query in the cache" do
    sql = Post.all.to_sql
    natural = with_reversal(false) { Post.find_by_sql(sql).map(&:id) }

    with_reversal(true) do
      Post.cache do
        assert_equal natural.reverse, Post.all.map(&:id)
        assert_equal natural, Post.find_by_sql(sql).map(&:id)
      end
    end

    with_reversal(true) do
      Post.cache do
        assert_equal natural, Post.find_by_sql(sql).map(&:id)
        assert_equal natural.reverse, Post.all.map(&:id)
      end
    end
  end

  test "asynchronous queries are reversed" do
    plucked, loaded = with_reversal(false) { [Post.pluck(:id), Post.all.map(&:id)] }

    with_reversal(true) do
      assert_equal plucked.reverse, Post.async_pluck(:id).value
      assert_equal loaded.reverse, Post.all.load_async.to_a.map(&:id)
    end
  end

  test "asynchronous association loads are reversed" do
    author = authors(:david)
    ids = with_reversal(false) { author.posts.reload.map(&:id) }

    with_reversal(true) do
      author.association(:posts).reset
      assert_equal ids.reverse, author.posts.load_async.to_a.map(&:id)
    end
  end

  test "adapter select_one and select_value follow the reversal" do
    with_reversal(false) do
      @natural_one = Post.lease_connection.select_one(Post.all.arel)["id"]
      @natural_value = Post.lease_connection.select_value(Post.select(:id).arel)
    end

    with_reversal(true) do
      assert_not_equal @natural_one, Post.lease_connection.select_one(Post.all.arel)["id"]
      assert_not_equal @natural_value, Post.lease_connection.select_value(Post.select(:id).arel)
    end
  end

  test "select_all accepts an explicit reverse_rows through the public entry point" do
    arel = Post.all.arel

    with_reversal(false) do
      natural = Post.lease_connection.select_all(arel).rows

      assert_equal natural.reverse,
        Post.lease_connection.select_all(arel, "Post Load", reverse_rows: true).rows
    end
  end

  test "order dependent finders are unaffected" do
    with_reversal(true) do
      assert_equal Post.order(:id).first, Post.first
      assert_equal Post.order(:id).last, Post.last
    end
  end

  test "counts are unaffected" do
    count = with_reversal(false) { Post.count }

    assert_equal count, with_reversal(true) { Post.count }
  end

  test "exists? is unaffected" do
    with_reversal(true) do
      assert_predicate Post, :exists?
      assert_not_predicate Post.where(id: -1), :exists?
    end
  end

  private
    # Deliberately does not disable the query cache: whether the reversal
    # survives caching is part of what these tests check.
    def with_reversal(value)
      ActiveRecord.reverse_unordered_selects = value
      yield
    ensure
      ActiveRecord.reverse_unordered_selects = @original
    end
end
