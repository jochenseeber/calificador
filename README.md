# What is it?

A small Gem that lets you write concise and readable unit tests. It is heavily inspired by [Minitest], [Factory Bot], and [Assertive Expressive] but tries to boil everything down to be as concise as possible:

```ruby
    module ReadMe
      require "calificador"

      # Define class to test
      class HighTea
        attr_accessor :scones, :posh

        def initialize(scones:)
          raise ArgumentError, "Cannot have a negative amount of scones" if scones.negative?

          @scones = scones
        end

        def eat_scone
          raise "Out of scones" if scones.zero?

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
          # Set properties on the created object
          posh { false }

          # Define transient properties that will not be set automatically
          transient do
            # Constructor arguments are automatically set from properties
            scones { 2 }
          end

          # Use traits to define variants of your test subject
          trait :style do
            posh { true }
          end
        end

        # Test class methods
        type do
          operation :new do
            must "set a default amount of scones" do
              # Write assertions using plain Ruby methods instead of spec DSL methods
              assert { subject.scones } > 0
            end

            must "provide an instance that has tea" do
              refute { subject.tea }.nil?
            end
          end
        end

        # Get nice test names. This one will be called "HighTea must let me have a scone"
        must "let me have a scone" do
          count = subject.scones
          subject.eat_scone
          assert { subject.scones } == count - 1
        end

        # Modify test subject using traits or properties for minor variations
        must "complain if out of scones", props { scones { 0 } } do
          assert { subject.eat_scone }.raises?(StandardError)
        end

        # Create subcontexts for variations of the test subject using traits and properties
        with :style do
          # Still nice test names. This one is "HighTea with style must have expensive tea"
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

* Test structure: examine, type, operation, where/with/without, must
* Factory methods: factory, mock, traits
* Assertions: assert, refute and raises?

It also tries to keep things simple by avoiding all the special assertion and expectation methods you need to learn for other test frameworks. Instead of having to learn that `include` is the RSpec matcher for `include?`, or Minitest's `assert_match` is used to assert regular expression matches, you can write `refute { something }.include? "value"` or `assert { something }.match %r{pattern}` using Ruby's normal `String#match` method.


## Frequently asked questions

Q: What's with the name?

A: In the [Spanish Inquisition](https://en.wikipedia.org/wiki/Spanish_Inquisition), a defendant was examined by calificadores, who determined if there was heresy involved.

Q: The Spanish Inquisition? I did not expect that.

A: Well, [nobody expects the Spanish Inquisition](https://www.youtube.com/watch?v=sAn7baRbhx4).