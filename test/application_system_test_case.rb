require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  setup do
    run_system_tests = ENV["RUN_SYSTEM_TESTS"] == "1" || ENV["CI"] == "true"
    skip "Set RUN_SYSTEM_TESTS=1 to run browser system tests" unless run_system_tests
  end
end
