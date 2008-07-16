require "rubygems"
require "spec_helper"
require File.join(File.dirname(__FILE__), '..', 'lib', 'context.rb')

describe "An object with a method declared in a context" do
  include InContext::WithContext

  before(:each) do
    @klass = Class.new do
      include InContext
      in_context :callable do
        def call
          @called = true
        end
      end
      def called?; @called; end
    end
    @object = @klass.new
    @object.should_not be_called
  end
  
  it "should not respond to the method" do
    lambda { @object.call }.should raise_error(NoMethodError)
  end

  it "should respond to the method in a context" do
    with_context(:callable) { @object.call }
    @object.should be_called
  end

  it "should not respond to the method once the context is complete" do
    with_context(:callable) { @object.call }
    lambda { @object.call }.should raise_error(NoMethodError)
  end

  it "should call the method in context after the instance method is redefined" do
    @klass.send(:define_method, :call) { :noop }
    with_context(:callable) { @object.call }
    @object.should be_called
    lambda { @object.call.should == :noop }
  end

  describe "when the context is opened again" do
    it "should redefine the method" do
      @klass.in_context(:callable) { def call; :redefined; end }
      with_context(:callable) { @object.call.should == :redefined }
    end
    
    it "should define other methods" do
      @klass.in_context(:callable) { def other; :other; end }
      with_context(:callable) {
        @object.call
        @object.other.should == :other
      }
      @object.should be_called
    end
  end
end

describe "An object with an instance method, and the same method declared in a context" do
  include InContext::WithContext
  
  before(:each) do
    @klass = Class.new do
      include InContext
      def the_context(collector); collector << :instance; end
      in_context(:override) do
        def the_context(collector); collector << :singleton; end
      end
    end

    @object = @klass.new
    @collector = []
  end

  it "should call the overridden method in context, and the original method in default context" do
    with_context(:override) { @object.the_context @collector }
    @object.the_context @collector
    @collector.should == [:singleton, :instance]
  end
end

describe "An object instantiated within a context" do
  include InContext::WithContext

  before(:each) do
    @klass = Class.new do
      include InContext
      in_context :callable do
        def call
          @called = true
        end
      end
      def called?; @called; end
    end
  end

  it "should respond to methods granted by context" do
    with_context(:callable) do
      @new_object = @klass.new
      @new_object.call
      @new_object.should be_called
    end
  end

  it "should not respond to methods after context removed" do
    with_context(:callable) { @new_object = @klass.new }
    lambda { @new_object.call }.should raise_error(NoMethodError)
  end
end

describe "An object should retain super semantics in context" do
  include InContext::WithContext
  
  before(:each) do
    @klass = Class.new do
      include InContext
      def the_context(collector); collector << :instance; end
      in_context(:override) do
        def the_context(collector); collector << :singleton; super end
      end
    end

    @object = @klass.new
    @collector = []
  end
  
  it "should call super within context" do
    with_context(:override) { @object.the_context @collector }
    @collector.should == [:singleton, :instance]
  end
end

describe "overwriting singleton methods" do
  include InContext::WithContext
  
  before(:each) do
    @klass = Class.new do
      include InContext
      in_context(:override) do
        def the_context(collector); collector << :contextual_singleton; end
      end
    end

    @object = @klass.new
    
    def @object.the_context(collector); collector << :singleton; end
    @collector = []
  end
  
  it "should not destroy singleton methods" # do
  #   with_context(:override) { @object.the_context @collector }
  #   @object.the_context @collector
  #   @collector.should == [:contextual_singleton, :singleton]
  # end
end