=begin rdoc
A module to parse the JEDICT.

= About the JEDICT 

The JEDICT (Japanese-English Dictionary) is the reference open-source Japanese-English dictionary. 
Find more informations about the JEDICT at http://www.jedict.com.

= jedict.rb

This module is an attempt at extracting the JEDICT from its XML format to a readily available in-memory structure.
Alternatively it can be used to perform read operations over the entire file without keeping the content in memory.

Its primary purpose is to allow for searches of arbitrary complexity through its data and ease the creation of custom databases.

=end 

require "nokogiri"

module JEDICT 

  def self.instanciate_from filename, eager_load
    raise "Invalid path #{filename}" unless FileTest.exist? filename
    DictionaryProxy.new(filename, eager_load)
  end

  def self.[] filename, eager_load = false
    instanciate_from filename, eager_load
  end

  def self.new file: File.join(__dir__, '../assets/jedict'), eager: false
    instanciate_from file, eager
  end

  class DictionaryProxy 

    def method_missing sym, *args, &blck
      return @dic.send(sym, *args, &blck) if @dic && @dic.respond_to?(sym)
      super
    end

    def initialize filename, eager_load
      @filename = filename 
      @dic = eager_load ? JEDICT::load_file(filename) : nil
    end

    def count 
      @count ||= (@dic && @dic.length) || JEDICT::load_file(@filename, Parser::Count.new)
    end

    def each_entry &blck
      raise "Block expected" unless blck
      JEDICT::load_file @filename, Parser::Entry.new(blck)
    end

  end

  def self.load_file filename, parser = Parser::Full.new
    Nokogiri::XML::SAX::Parser.new(parser).parse(File.open(filename))
    parser.value
  end

  def self.format_node n, pre = ""
    if n.is_a? Array
      n.reduce("") do |s, e| 
        s + pre + format_node(e, pre + "  ") 
      end
    elsif n.is_a? Hash
      n.to_a.reduce("") do |s, e|
        key, value = *e
        s + "\n" + pre + ((key == :value) ? "" : key.to_s  + ": ") + format_node(value, pre + "  ")
      end
    else 
      n.to_s
    end
  end

  module NodeExtention
    PATHS = {
      meaning: [:sense, :gloss, :value],
      kanji_representation: [:k_ele, :keb, :value],
      reading_representation: [:r_ele, :reb, :value],
      kanji_priority: [:k_ele, :ke_pri, :value],
      reading_priority: [:r_ele, :re_pri, :value],
      kanji_information: [:k_ele, :ke_inf, :value],
      reading_information: [:r_ele, :re_inf, :value],
      sense_information: [:sense, :s_inf, :value],
      gramatical_position: [:sense, :pos, :value],
      lexical_field: [:sense, :field, :value],
      dialect: [:sense, :dial, :value],
#      primary_meaning: [:sense, :gloss, :pri, :value], # In the documentation but doesn't actually appear in the dictionnary at the time of writing (2017/12/17)
    }
    def to_s
      JEDICT::format_node(self).strip
    end

    def self.elements_at node, path, *args
      if args.length == 0
        if node.is_a? Hash
          [node[path]].flatten.compact
        elsif node.is_a? Array
          node.map { |e| e[path] }.flatten.compact
        else
          [node]
        end
      else
        if node.is_a? Array
          node.map { |e| elements_at e[path], *args }.flatten.compact
        elsif node.is_a? Hash
          elements_at(node[path], *args).flatten.compact
        else
          []
        end
      end
    end

    PATHS.each do |key, path|
      define_method key do
        NodeExtention::elements_at self, *path
      end

      define_method "#{key}?" do |param|
        send(key).include?(param)
      end

      define_method "#{key}_is_one_of?" do |array|
        (send(key) - array).length > 0
      end

      define_method "#{key}_matches?" do |regex|
        send(key).reduce(false) { |acc, r| acc and r.match(regex) }
      end
    end

  end


  module  Parser

    class Entry < Nokogiri::XML::SAX::Document
      attr_accessor :callback, :parents, :position

      def initialize prc
        @callback = prc
        @parents = []
        @position = {} 
      end

      def start_element(name, attrs)
        return if name == "JMdict"
        name = name.to_sym
        pos = position[name]
        if !pos
          self.position[name] = {}
        elsif pos.is_a? Array 
          position[name] << {}
        else
          self.position[name] = [pos, {}]
        end
        self.parents << position
        self.position = position[name]
        self.position = position[-1] if position.is_a? Array
        self.position[:attrs] = attrs.flatten if attrs.flatten.length > 0
      end

      def characters(string)
        string.gsub!(/[\n]/, "")
        string.strip!
        position[:value] = string unless string == ""
      end

      def end_element(name)
        self.position = parents.pop
        if name == "entry"
          position[:entry].extend NodeExtention
          callback.call(position[:entry])
          self.position = {}
          self.parents = []
        end
      end

      def value
        nil
      end

    end

    class Full < Entry 
      attr_accessor :value
      def initialize
        @value = []
        super(proc { |e| value << e })
      end
    end

    class Count < Nokogiri::XML::SAX::Document
      attr_accessor :value

      def initialize 
        @value = 0
      end

      def start_element(name, attrs)
        @value += 1 if name == "entry"
      end
    end

  end


end



