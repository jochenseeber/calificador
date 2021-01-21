## What is it?

A small Gem that lets you write concise and readable unit tests. It is heavily inspired by [Minitest], [Factory Bot], and [Assertive Expressive] but tries to boil everything down to be as concise as possible:

```ruby
    module ReadMe
      require "calificador"

      # Define a test class
      class HighTea
        attr_accessor :scones, :posh

        def eat_scone
          raise "Out of scones" if scones == 0

          @scones -= 1
        end

        def tea
          @posh ? "Darjeeling First Flush" : "Earl Grey"
        end
      end

      # Unit test
      class HighTeaTest < Calificador::Test
        examines HighTea

        # Define a factory for the test subject
        factory HighTea do
          scones { 2 }
          posh { false }

          # Use raits to define variants of your test subject
          trait :style do
            posh { true }
          end
        end

        # Define test method
        must "have tea and scones" do
          # Write assertions using plain Ruby methods instead of spec DSL methods
          refute { subject.tea }.nil?
          assert { subject.scones } > 0
        end

        # Get nice test names. This one will be called "HighTea must have me let a scone"
        must "let me have a scone" do
          count = subject.scones
          subject.eat_scone
          assert { subject.scones } == count - 1
        end

        # Adjust test subject using traits or properties for minor variations
        must "complain if out of scones", scones: 0 do
          assert { subject.eat_scone }.raises?(StandardError)
        end

        # Create subcontexts for variations of the test subject using traits and properties
        with :style do
          # Still nice test names. This one is "HighTea with style should have expensive tea"
          must "have expensive tea" do
            assert { subject.tea }.include?("First Flush")
          end
        end
      end
    end

    ReadMe::HighTeaTest.run_all_tests
```

[Minitest]: https://github.com/seattlerb/minitest
[Factory Bot]: https://github.com/thoughtbot/factory_bot
[Shoulda Context]: https://github.com/thoughtbot/shoulda-context
[Assertive Expressive]: https://github.com/rubyworks/ae

## Why?

Calificador is an experiment in getting rid of as much mental load, boilerplate and distractions as possible. It tries to create a simple, easy to learn and easy to understand DSL for unit tests.

Only a handful of DSL methods are required:

* Test structure: examine, must, where/with/without
* Factory methods: factory, traits
* Assertions: assert, refute and raises?

It also tries to keep things simple by avoiding all the special assertion and expectation methods you need to learn for other test frameworks. Instead of having to learn that `include` is the RSpec matcher for `include?`, or Minitest's `assert_match` is used to assert regular expression matches, you can write `refute { something }.include? "value"` or `assert { something }.match %r{pattern}` using Ruby's normal `String#match` method.


## Frequently asked questions

Q: What's with the name?

A: In the [Spanish Inquisition](https://en.wikipedia.org/wiki/Spanish_Inquisition), a defendant was examined by calificadores, who determined if there was heresy involved.

Q: The Spanish Inquisition? I did not expect that.

A: Well, [nobody expects the Spanish Inquisition](https://www.youtube.com/watch?v=sAn7baRbhx4).