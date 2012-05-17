require "#{File.dirname(__FILE__)}/../urm.rb"
require "#{File.dirname(__FILE__)}/native_program.rb"

describe URM do
  it "executes an inc-op" do
    p = NativeProgram.new([
      { :op => :inc, :arg =>[1] },
      { :op => :halt }
    ], [], [0, 1])
    results = URM.run(p)
    
    results[1].should eq(2)
  end
  
  it "executes a dec-op" do
    p = NativeProgram.new([
      { :op => :dec, :arg =>[1] },
      { :op => :halt }
    ], [], [0, 1])
    results = URM.run(p)
    
    results[1].should eq(0)
  end
  
  it "ensures that dec-op never makes a register < 0" do
    p = NativeProgram.new([
      { :op => :dec, :arg =>[1] },
      { :op => :halt }
    ], [], [0, 0])
    results = URM.run(p)
    
    results[1].should eq(0)
  end
  
  it "executes a relative jmp-op" do
    p = NativeProgram.new([
      { :op => :inc, :arg => [1] },
      { :op => :jmp, :arg => [2] },
      { :op => :dec, :arg => [1] },
      { :op => :halt }
    ], [], [0, 0])
    results = URM.run(p)
    
    results[1].should eq(1)
  end
  
  it "executes a relative jz-op" do
    p = NativeProgram.new([
      { :op => :jz, :arg => [1,2] },
      { :op => :dec, :arg => [1] },
      { :op => :inc, :arg => [1] },
      { :op => :halt }
    ], [], [0, 0])
    results = URM.run(p)
    
    results[1].should eq(1)
  end
end