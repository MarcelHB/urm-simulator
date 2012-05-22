require "stringio"
require "#{File.dirname(__FILE__)}/../urm.rb"
require "#{File.dirname(__FILE__)}/../goto_program.rb"

describe GotoProgram do
  it "can parse an atomic incrementation" do
    program = <<-PROGRAM
    1: R1 := R1 + 1; 2
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 0])
    p.errors.length.should eq(0)
  end

  it "can parse an atomic decrementation" do
    program = <<-PROGRAM
    1: R1 := R1 - 1; 2
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 0])
    p.errors.length.should eq(0)
  end

  it "can parse a condition" do
    program = <<-PROGRAM
    1: IF R3 = 0: 2; 2
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 0])
    p.errors.length.should eq(0)
  end

  it "can parse multiple statements" do
    program = <<-PROGRAM
    1: R1 := R1 + 1; 2
    2: R2 := R2 + 2; 3
    3: IF R2 = 0: 4; 1
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 0])
    p.errors.length.should eq(0)
  end

  it "compiles a reflexive addition" do
    program = <<-PROGRAM
    1: R1 := R1 + 1; 2
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 0])
    result = URM.run(p)
    result[1].should eq(1)
  end

  it "compiles an addition" do
    program = <<-PROGRAM
    1: R2 := R1 + 2; 2
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 1, 0])
    result = URM.run(p)
    result[1].should eq(1)
    result[2].should eq(3)
  end

  it "compiles a reflexive subtraction" do
    program = <<-PROGRAM
    1: R1 := R1 - 1; 2
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 1])
    result = URM.run(p)
    result[1].should eq(0)
  end

  it "compiles a subtraction" do
    program = <<-PROGRAM
    1: R2 := R1 - 2; 2
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 3, 0])
    result = URM.run(p)
    result[1].should eq(3)
    result[2].should eq(1)
  end

  it "compiles a condition against 0" do
    program = <<-PROGRAM
    1: IF R1 = 0: 2; 3
    2: R2 := R2 + 1; 4
    3: R2 := R2 - 1; 4
    4: IF R0 = 0: 5; 6
    5: R3 := R3 + 1; 6
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 1, 1, 1])
    result = URM.run(p)
    result[1].should eq(1)
    result[2].should eq(0)
    result[3].should eq(2)
  end

  it "compiles a condition against a positive constant" do
    program = <<-PROGRAM
    1: IF R1 = 2: 2; 3
    2: R2 := R2 + 1; 4
    3: R2 := R2 - 1; 4
    4: IF R1 = 3: 5; 6
    5: R3 := R3 + 1; 6
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 3, 1, 1])
    result = URM.run(p)
    result[1].should eq(3)
    result[2].should eq(0)
    result[3].should eq(2)
  end

  it "compiles a condition against a positive constant with backward jumps" do
    program = <<-PROGRAM
    1: R1 := R1 + 1; 2
    2: R2 := R2 - 1; 3
    3: IF R2 = 0: 4; 1
    4: R2 := R2 + 1; 5
    5: IF R2 = 1: 4; 6
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 0, 3])
    result = URM.run(p)
    result[1].should eq(3)
    result[2].should eq(2)
  end

  it "ignores comments in the source code" do
    program = <<-PROGRAM
    1: R1 := R1 + 1; 2
    # 2: R1 := R1 - 1; 3
    2: R1 := R1 + 1; 3
    # 3: R2 := R2 + 1; 4
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 1, 0])
    result = URM.run(p)
    result[1].should eq(3)
    result[2].should eq(0)
  end

  it "does not allow a label to jump to its own" do
    program = <<-PROGRAM
    1: R1 := R1 + 1: 1
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 1])
    p.errors.length.should eq(1)
  end

  it "does not allow a condition to jump to its own if true" do
    program = <<-PROGRAM
    1: IF R1 = 0: 1; 2
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 1])
    p.errors.length.should eq(1)
  end

  it "does not allow a condition to jump to its own if false" do
    program = <<-PROGRAM
    1: IF R1 = 0: 2; 1
    PROGRAM
    p = GotoProgram.new(StringIO.new(program), [0, 1])
    p.errors.length.should eq(1)
  end
end
