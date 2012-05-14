require "stringio"
require "benchmark"

require "#{File.dirname(__FILE__)}/urm_program"
require "#{File.dirname(__FILE__)}/loop_program"
require "#{File.dirname(__FILE__)}/goto_program"
require "#{File.dirname(__FILE__)}/urm"
require "#{File.dirname(__FILE__)}/cheating_urm"

# test run script, move along ...

if __FILE__ == $0
  #p = URMProgram.new(StringIO.new("(A3;A4;S1)1;((A1;S3)3;S2;(A0;A3;S4)4;(A4;S0)0)2"), [0, 1, 2, 3, 4])
  #p = URMProgram.new(StringIO.new("(C(3;4);(A1;S4)4;S2)2;(S3)3"), [0, 0, 500, 600])
  #p = LoopProgram.new(StringIO.new("(C(3;4);(A1;S4)4;S2)2;(S3)3"), [0, 0, 500, 600])
  File.open("misc/goto.txt", "rb") do |file|
    p = GotoProgram.new(file, [0, 0, 500, 600])
    puts p.errors
    puts p.instructions
  
    Benchmark.bm do |x|
      x.report { puts URM.run(p) }
    end
  end
end
