require "stringio"
require "#{File.dirname(__FILE__)}/../urm.rb"
require "#{File.dirname(__FILE__)}/../loop_program.rb"

# better think of non-trivial tests...
describe LoopProgram do
  it "can parse an atomic A-operation" do
    p = LoopProgram.new(StringIO.new("A1"), [0, 0])
    p.errors.length.should eq(0)
  end

  it "can parse an atomic S-operation" do
    p = LoopProgram.new(StringIO.new("S1"), [0, 0])
    p.errors.length.should eq(0)
  end

  it "can parse an atomic C-operation" do
    p = LoopProgram.new(StringIO.new("C(0,1)"), [0, 0])
    p.errors.length.should eq(0)
  end

  it "can parse an atomic R-operation" do
    p = LoopProgram.new(StringIO.new("R(0,1)"), [0, 0])
    p.errors.length.should eq(0)
  end

  it "can parse multiple atomic operations" do
    p = LoopProgram.new(StringIO.new("A1;S1;C(0,1);R(0,1)"), [0, 0])
    p.errors.length.should eq(0)
  end

  it "can parse an iteration" do
    p = LoopProgram.new(StringIO.new("(A1;S2)2"), [0, 0, 0])
    p.errors.length.should eq(0)
  end

  it "can parse nested iterations" do
    p = LoopProgram.new(StringIO.new("(A1;(A1;S0)0;S2)2"), [0, 0, 0])
    p.errors.length.should eq(0)
  end
  
  it "can parse an organic program" do
    p = LoopProgram.new(StringIO.new("(C(3;4);(A1;S4)4;S2)2;(S3)3"), [0, 0, 0])
    p.errors.length.should eq(0)
  end

  it "does not allow unmatched brackets" do
    p = LoopProgram.new(StringIO.new("(A1; S2 2"), [0, 0, 0])
    p.errors.length.should eq(1)
  end

  it "compiles an A-operation as incrementation" do
    p = LoopProgram.new(StringIO.new("A1"), [0, 0])
    result = URM.run(p)
    result[1].should eq(1)
  end

  it "compiles an S-operation as decrementation" do
    p = LoopProgram.new(StringIO.new("S1"), [0, 1])
    result = URM.run(p)
    result[1].should eq(0)
  end

  it "compiles a C-operation as additive-copy operation" do
    p = LoopProgram.new(StringIO.new("C(1;2,3)"), [0, 1, 2, 3])
    result = URM.run(p)
    result[0].should eq(0)
    result[1].should eq(1)
    result[2].should eq(3)
    result[3].should eq(4)
  end

  it "compiles an R-operation as additive-copy operation with cleared source" do
    p = LoopProgram.new(StringIO.new("R(1;2,3)"), [0, 1, 2, 3])
    result = URM.run(p)
    result[0].should eq(0)
    result[1].should eq(0)
    result[2].should eq(3)
    result[3].should eq(4)
  end

  it "compiles an iteration to a loop" do
    p = LoopProgram.new(StringIO.new("(A1;A1;S2)2"), [0, 0, 2])
    result = URM.run(p)
    result[1].should eq(4)
    result[2].should eq(0)
  end

  it "compiles a multiplication" do
    p = LoopProgram.new(StringIO.new("(C(3;4);(A1;S4)4;S2)2;(S3)3"), [0, 0, 10, 20])
    result = URM.run(p)
    result[1].should eq(200)
  end

  it "does not allow modifying the iterator somewhere" do
    p = LoopProgram.new(StringIO.new("(A1;S1)1"), [0, 0])
    p.errors.length.should eq(1)
  end

  it "does not allow modifying the iterator (subiteration)" do
    p = LoopProgram.new(StringIO.new("(A1;(A2;S1)1;S1)1"), [0, 0])
    p.errors.length.should eq(1)
  end

  it "does not allow Sx anywhere but the end" do
    p = LoopProgram.new(StringIO.new("(S1;A1)1"), [0, 0])
    p.errors.length.should eq(1)
  end

  it "always requires an Sx for an iteration" do
    p = LoopProgram.new(StringIO.new("(A2)1"), [0, 0])
    p.errors.length.should eq(1)
  end
end
