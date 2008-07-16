require File.join(File.dirname(__FILE__), 'extensions', 'object.rb')

# Allows for context-specific object behavior. Contexts are specified
# in the class. Based on github.com/pat-maddox/with_context. I wanted
# to see if I could do it without method_missing. Turns out I could, but
# it wasn't worth it (in terms of performance).
module InContext
  def self.included(base)
    ContextClass.add(base)
    base.extend(ClassMethods)
    base.override_new!
  end
  
  module ClassMethods
    def in_context(name, &block)
      ContextClass.get(self).add_context(name, &block)
    end
    
    # For ensuring that objects instantiated within contexts get
    # contextual behavior.
    # 
    # It'd be interesting to use with_context to only override the
    # #new method within a context.
    def override_new!
      class << self
        alias_method :new_without_context, :new
        def new_with_context(*args)
          obj = new_without_context(*args)
          return obj unless ContextClass.current_context
          contexts = ContextClass.get(self).contexts[ContextClass.current_context]
          contexts.each do |p|
            obj.instance_eval(&p)
          end
          return obj
        end
        alias_method :new, :new_with_context
      end
    end
  end
  
  module WithContext
    def with_context(name, &block)
      ContextClass.use_context(name)
      yield
      ContextClass.remove_context(name)
    end
  end
  
  # Used for adding/removing contextual behaviors to objects of classes
  # with contexts. Also tracks current context.
  class ContextClass
    class << self
      # Add a context class.
      def add(klass)
        @@klasses ||= { }
        @@klasses[klass] = new(klass)
      end
      
      # Retrieve a context class.
      def get(klass)
        @@klasses[klass]
      end
      
      # Give all context classes behavior.
      def use_context(name)
        @@current_context = name
        context_classes_for(name).each do |klass|
          klass.use_context(name)
        end
      end
      
      def remove_context(name)
        @@current_context = nil
        context_classes_for(name).each do |klass|
          klass.remove_context(name)
        end
      end
      
      def current_context
        @@current_context rescue nil
      end
      
      private
      
      def context_classes_for(name)
        @@klasses.values.select { |klass| klass.has_context?(name) }
      end
    end
    
    attr_reader :klass, :contexts
    
    def initialize(klass)
      @klass = klass
      @contexts = Hash.new([])
    end
    
    def add_context(name, &block)
      @contexts[name] << proc(&block)
      @context_methods = nil
    end
    
    def use_context(name)
      each_object do |obj|
        contexts[name].each { |p| obj.instance_eval(&p) }
      end
    end
    
    def remove_context(name)
      methods = context_methods(name)
      each_object do |obj|
        methods.each { |m| obj.meta_eval { remove_method(m) } }
      end
    end
    
    def context_methods(name)
      @context_methods ||= begin
        methods = contexts[name].map { |p| Module.new(&p).instance_methods }
        methods.flatten!
        methods.uniq!
        methods
      end
    end
    
    def each_object(&block)
      ObjectSpace.each_object(@klass, &block)
    end
    
    def has_context?(name)
      @contexts[name]
    end
  end
end
