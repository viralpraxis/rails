*   Add `assert_part` and `assert_no_part` to `ActionMailer::TestCase`

    ```ruby
    test "assert MyMailer.welcome HTML and text parts" do
      mail = MyMailer.welcome("Hello, world")

      assert_part :text, mail do |text|
        assert_includes text, "Hello, world"
      end
      assert_part :html, mail do |html|
        assert_dom html.root, "p", "Hello, world"
      end
    end
    ```

    *Sean Doyle*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionmailer/CHANGELOG.md) for previous changes.

*   Add support for `only` and `except` options for ActionMailer delivery callbacks.

    Before:

    ```ruby
    before_deliver :perform_action, if: -> { action_name == 'reset_email' }
    ```

    After:

    ```ruby
    before_deliver :perform_action, only: :reset_email
    ```

    Added a configuration option `action_mailer.raise_on_missing_callback_actions` to mirror `action_controller.raise_on_missing_callback_actions`.

    *viralpraxis*
