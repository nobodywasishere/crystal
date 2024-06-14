require "../../../spec_helper"

private def assert_text_namespaces(source, filter, expected, *, file = __FILE__, line = __LINE__)
  program = semantic(source).program
  output = String.build { |io| Crystal.print_namespaces(program, io, filter, "text") }
  output.should eq(expected), file: file, line: line
end

private def assert_json_namespaces(source, filter, expected, *, file = __FILE__, line = __LINE__)
  program = semantic(source).program
  output = String.build { |io| Crystal.print_namespaces(program, io, filter, "json") }
  JSON.parse(output).should eq(JSON.parse(expected)), file: file, line: line
end

describe Crystal::TextNamespacesPrinter do
  it "works" do
    assert_text_namespaces <<-CRYSTAL, "Foo", <<-EOS
      class Foo
        annotation Baz
        end

        module Fizz
          abstract struct Buzz
          end
        end
      end

      class Foo::Bar < Foo
      end

      struct Foo::Fizz::Buzz
      end
      CRYSTAL
      - class Foo
        @ :1:1
      - class Foo::Bar
        @ :11:1
      - annotation Foo::Baz
        @ :2:3
      - module Foo::Fizz
        @ :5:3
      - struct Foo::Fizz::Buzz
        @ :6:5
        @ :14:1\n
      EOS
  end
end

describe Crystal::JSONNamespacesPrinter do
  it "works" do
    assert_json_namespaces <<-CRYSTAL, "Foo", <<-JSON
      class Foo
        annotation Baz
        end

        module Fizz
          abstract struct Buzz
          end
        end
      end

      class Foo::Bar < Foo
      end

      struct Foo::Fizz::Buzz
      end
      CRYSTAL
      [
        {"name": "Foo", "kind": "class", "locations": [":1:1"]},
        {"name": "Foo::Bar", "kind": "class", "locations": [":11:1"]},
        {"name": "Foo::Baz", "kind": "annotation", "locations": [":2:3"]},
        {"name": "Foo::Fizz", "kind": "module", "locations": [":5:3"]},
        {
          "name": "Foo::Fizz::Buzz",
          "kind": "struct",
          "locations": [":6:5", ":14:1"]
        }
      ]
      JSON
  end

  it "supports macros" do
    assert_json_namespaces <<-CRYSTAL, "Foo", <<-JSON
      macro my_macro
        class Foo
          annotation Baz
          end

          module Fizz
            abstract struct Buzz
            end
          end
        end
      end

      my_macro

      class Foo::Bar < Foo
      end

      struct Foo::Fizz::Buzz
      end
      CRYSTAL
      [
        {"name": "Foo", "kind": "class", "locations": [":2:3"]},
        {"name": "Foo::Bar", "kind": "class", "locations": [":15:1"]},
        {"name": "Foo::Baz", "kind": "annotation", "locations": [":3:5"]},
        {"name": "Foo::Fizz", "kind": "module", "locations": [":6:5"]},
        {
          "name": "Foo::Fizz::Buzz",
          "kind": "struct",
          "locations": [":7:7", ":18:1"]
        }
      ]
      JSON
  end

  it "supports enum values" do
    assert_json_namespaces <<-CRYSTAL, "Foo", <<-JSON
      class Foo
        enum Baz
          VALUE_1
          VALUE_2
          VALUE_3
          VALUE_4
        end
      end
      CRYSTAL
      [
        {"name": "Foo", "kind": "class", "locations": [":1:1"]},
        {"name": "Foo::Baz", "kind": "enum", "locations": [":2:3"]},
        {"name": "Foo::Baz::VALUE_1", "kind": "const", "locations": [":3:5"]},
        {"name": "Foo::Baz::VALUE_2", "kind": "const", "locations": [":4:5"]},
        {"name": "Foo::Baz::VALUE_3", "kind": "const", "locations": [":5:5"]},
        {"name": "Foo::Baz::VALUE_4", "kind": "const", "locations": [":6:5"]}
      ]
      JSON
  end
end
