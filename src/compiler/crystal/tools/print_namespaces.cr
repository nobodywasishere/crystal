require "set"
require "colorize"
require "../syntax/ast"

module Crystal
  def self.print_namespaces(program, io, exp, format)
    case format
    when "text"
      TextNamespacesPrinter.new(program, io, exp).print_all
    when "json"
      JSONNamespacesPrinter.new(program, io, exp).print_all
    else
      raise "Unknown namespaces format: #{format}"
    end
  end

  abstract class NamespacesPrinter
    abstract def print_all

    def initialize(@program : Program, exp : String?)
      @exp = exp ? Regex.new(exp) : nil
    end

    private def collect_types(types : Array(Type))
      collected = Set(NamedType).new

      types.each do |type|
        next unless type.is_a?(NamedType)

        collected.add(type)

        if type.struct? || type.class? || type.metaclass?
          collected.concat collect_types(type.subclasses)
        end

        if sub_types = type.types?
          collected.concat collect_types(sub_types.values)
        end
      end

      collected
    end

    protected def location_to_s(loc : Location)
      f = loc.filename
      case f
      when String
        line = loc.line_number
        column = loc.column_number
        filename = f
      when VirtualFile
        macro_location = f.macro.location.not_nil!
        filename = macro_location.filename.to_s
        line = macro_location.line_number + loc.line_number
        column = loc.column_number
      else
        raise "not implemented"
      end

      "#{filename}:#{line}:#{column}"
    end
  end

  class TextNamespacesPrinter < NamespacesPrinter
    def initialize(program : Program, @io : IO, exp : String?)
      super(program, exp)
    end

    def print_all
      types = collect_types(@program.types.values)
      types = types.to_a.sort_by(&.full_name)

      types.each do |type|
        print_type(type)
      end
    end

    def print_type(type : NamedType)
      return if (exp = @exp) && (exp !~ type.full_name)
      return if type.is_a?(MetaclassType)

      @io << "- "
      @io << case type
      in Const
        "const"
      in .struct?
        "struct"
      in .class?
        "class"
      in .module?
        "module"
      in AliasType
        "alias"
      in EnumType
        "enum"
      in NoReturnType, VoidType
        "struct"
      in AnnotationType
        "annotation"
      in LibType
        "module"
      in TypeDefType
        "typedef"
      in MetaclassType, NamedType
        ""
      end

      @io << " " << type.full_name

      if locations = type.locations
        @io << "\n"
        locations.each do |loc|
          @io << "  @ " << location_to_s(loc) << "\n"
        end
      end
    end
  end

  class JSONNamespacesPrinter < NamespacesPrinter
    def initialize(program : Program, io : IO, exp : String?)
      super(program, exp)
      @json = JSON::Builder.new(io)
    end

    def print_all
      types = collect_types(@program.types.values)
      types = types.to_a.sort_by(&.full_name)

      @json.document do
        @json.array do
          types.each do |type|
            print_type(type)
          end
        end
      end
    end

    def print_type(type : NamedType)
      return if (exp = @exp) && (exp !~ type.full_name)
      return if type.is_a?(MetaclassType)

      @json.object do
        @json.field("name", type.full_name)

        case type
        in Const
          @json.field("kind", "const")
        in .struct?
          @json.field("kind", "struct")
        in .class?
          @json.field("kind", "class")
        in .module?
          @json.field("kind", "module")
        in AliasType
          @json.field("kind", "alias")
        in EnumType
          @json.field("kind", "enum")
        in NoReturnType, VoidType
          @json.field("kind", "struct")
        in AnnotationType
          @json.field("kind", "annotation")
        in LibType
          @json.field("kind", "module")
        in TypeDefType
          @json.field("kind", "typedef")
        in MetaclassType, NamedType
        end

        if locations = type.locations
          @json.string("locations")
          @json.array do
            locations.each do |loc|
              @json.string(location_to_s(loc))
            end
          end
        end
      end
    end
  end
end
