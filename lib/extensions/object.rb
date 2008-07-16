class Object
  def metaclass; class << self; self; end; end
  def meta_eval(&b); metaclass.instance_eval(&b); end
end