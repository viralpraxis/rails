# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class ResultTest < ActiveRecord::TestCase
    def result
      Result.new(["col_1", "col_2"], [
        ["row 1 col 1", "row 1 col 2"],
        ["row 2 col 1", "row 2 col 2"],
        ["row 3 col 1", "row 3 col 2"],
      ], affected_rows: 3)
    end

    test "includes_column?" do
      assert result.includes_column?("col_1")
      assert_not result.includes_column?("foo")
    end

    test "length" do
      assert_equal 3, result.length
    end

    test "to_a returns row_hashes" do
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.to_a
    end

    test "first returns first row as a hash" do
      assert_equal(
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" }, result.first)
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
      ], result.first(1)
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
      ], result.first(2)
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.first(3)
    end

    test "last returns last row as a hash" do
      assert_equal(
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" }, result.last)
      assert_equal [
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.last(1)
      assert_equal [
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.last(2)
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.last(3)
    end

    test "each with block returns row hashes" do
      result.each do |row|
        assert_equal ["col_1", "col_2"], row.keys
      end
    end

    test "each without block returns an enumerator" do
      result.each.with_index do |row, index|
        assert_equal ["col_1", "col_2"], row.keys
        assert_kind_of Integer, index
      end
    end

    test "each without block returns a sized enumerator" do
      assert_equal 3, result.each.size
    end

    test "cast_values returns rows after type casting" do
      values = [["1.1", "2.2"], ["3.3", "4.4"]]
      columns = ["col1", "col2"]
      types = [Type::Integer.new, Type::Float.new]
      result = Result.new(columns, values, types)

      assert_equal [[1, 2.2], [3, 4.4]], result.cast_values
    end

    test "cast_values uses identity type for unknown types" do
      values = [["1.1", "2.2"], ["3.3", "4.4"]]
      columns = ["col1", "col2"]
      types = [Type::Integer.new]
      result = Result.new(columns, values, types)

      assert_equal [[1, "2.2"], [3, "4.4"]], result.cast_values
    end

    test "cast_values returns single dimensional array if single column" do
      values = [["1.1"], ["3.3"]]
      columns = ["col1"]
      types = [Type::Integer.new]
      result = Result.new(columns, values, types)

      assert_equal [1, 3], result.cast_values
    end

    test "cast_values can receive types to use instead" do
      values = [["1.1", "2.2"], ["3.3", "4.4"]]
      columns = ["col1", "col2"]
      types = [Type::Integer.new, Type::Float.new]
      result = Result.new(columns, values, types)

      assert_equal [[1.1, 2.2], [3.3, 4.4]], result.cast_values("col1" => Type::Float.new)
    end

    test "each when two columns have the same name" do
      result = Result.new(["foo", "foo"], [
        ["col 1", "col 2"],
        ["col 1", "col 2"],
        ["col 1", "col 2"],
      ])

      assert_equal 2, result.columns.size
      result.each do |row|
        assert_equal 1, row.size
        assert_equal "col 2", row["foo"]
      end
    end

    test "dup preserve all attributes" do
      a = result
      b = a.dup

      assert_equal a.column_types, b.column_types
      assert_equal a.columns, b.columns
      assert_equal a.rows, b.rows
      assert_equal a.column_indexes, b.column_indexes
      assert_equal a.affected_rows, b.affected_rows

      # Second round in case of mutation
      b = b.dup

      assert_equal a.column_types, b.column_types
      assert_equal a.columns, b.columns
      assert_equal a.rows, b.rows
      assert_equal a.column_indexes, b.column_indexes
      assert_equal a.affected_rows, b.affected_rows
    end

    test "column_types handles nil types in the column_types array" do
      values = [["1.1", "2.2"], ["3.3", "4.4"]]
      columns = ["col1", "col2"]
      types = [Type::Integer.new, nil]  # Deliberately nil type for col2
      result = Result.new(columns, values, types)

      assert_not_nil result.column_types["col1"]
      assert_not_nil result.column_types["col2"]

      assert_instance_of ActiveRecord::Type::Value, result.column_types["col2"]

      assert_nothing_raised do
        result.column_types["col2"].deserialize("test value")
      end
    end

    test "reverse_rows returns a copy with the rows reversed" do
      result = ActiveRecord::Result.new(["col_1", "col_2"], [["row 1 col 1", "row 1 col 2"], ["row 2 col 1", "row 2 col 2"]])
      reversed = result.reverse_rows

      assert_equal [["row 2 col 1", "row 2 col 2"], ["row 1 col 1", "row 1 col 2"]], reversed.rows
      assert_equal [{ "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" }, { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" }], reversed.to_a
      assert_equal "row 2 col 1", reversed.indexed_rows.first["col_1"]
    end

    test "reverse_rows leaves the receiver untouched" do
      rows = [["row 1 col 1", "row 1 col 2"], ["row 2 col 1", "row 2 col 2"]]
      result = ActiveRecord::Result.new(["col_1", "col_2"], rows)
      original = result.rows.dup

      result.reverse_rows

      assert_equal original, result.rows
      assert_equal original, rows, "the array handed to the constructor must not be mutated"
    end

    test "reverse_rows works on a frozen result whose caches are already warm" do
      result = ActiveRecord::Result.new(["col_1"], [["a"], ["b"], ["c"]]).freeze
      reversed = result.reverse_rows

      assert_not_predicate reversed, :frozen?
      assert_equal [["c"], ["b"], ["a"]], reversed.rows
      assert_equal ["c", "b", "a"], reversed.indexed_rows.map { |row| row["col_1"] }
      assert_equal [["a"], ["b"], ["c"]], result.rows
    end

    test "reverse_rows on an empty result" do
      assert_empty ActiveRecord::Result.empty.reverse_rows.rows
      assert_equal 3, ActiveRecord::Result.empty(affected_rows: 3).reverse_rows.affected_rows
    end
  end
end
