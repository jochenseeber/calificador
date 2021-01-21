# Test example

```ruby
    module Test
      require "calificador"

      class UserTest < Calificador::Test
        User = Struct.new(:name, :uid, keyword_init: true)

        examines User

        must "set user" do
          subject.name = "john.doe"
          assert { subject.name } == "john.doe"
        end
      end
    end

    Test::UserTest.run_all_tests
```
