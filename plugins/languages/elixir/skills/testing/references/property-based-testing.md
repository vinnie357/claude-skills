# Property-Based Testing

Use StreamData for property-based tests.

```elixir
defmodule MyApp.MathPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "addition is commutative" do
    check all a <- integer(),
              b <- integer() do
      assert Math.add(a, b) == Math.add(b, a)
    end
  end

  property "list reversal is involutive" do
    check all list <- list_of(integer()) do
      assert Enum.reverse(Enum.reverse(list)) == list
    end
  end

  property "concatenation length" do
    check all list1 <- list_of(term()),
              list2 <- list_of(term()) do
      concatenated = list1 ++ list2
      assert length(concatenated) == length(list1) + length(list2)
    end
  end
end
```

## Custom Generators

```elixir
defmodule MyApp.Generators do
  use ExUnitProperties

  def email do
    gen all username <- string(:alphanumeric, min_length: 1),
            domain <- string(:alphanumeric, min_length: 1),
            tld <- member_of(["com", "org", "net"]) do
      "#{username}@#{domain}.#{tld}"
    end
  end

  def user do
    gen all name <- string(:alphanumeric, min_length: 1),
            email <- email(),
            age <- integer(18..100) do
      %User{name: name, email: email, age: age}
    end
  end
end

# Use in tests
property "validates email format" do
  check all email <- MyApp.Generators.email() do
    assert User.valid_email?(email)
  end
end
```
