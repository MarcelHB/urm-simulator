require "#{File.dirname(__FILE__)}/urm"

# naive URM on ruby is slow, 3*10^6 instructions took ~1.5 sec, v1.9.3, Core i7
# this one is much faster: cut :inc/:dec by looking down the pipeline and do the
# calculation in one step

class CheatingURM < URM  
    #----------------------------------------------------------------------------
  def start!
    if program.errors.empty?
      prealloc_registers!
      until @stopped
        instruction = @program.instructions[@idx]
        args = instruction[:arg]

        case instruction[:op]
        when :inc
          @registers[args[0]] += 1
        when :dec
          if @registers[args[0]] > 0
            @registers[args[0]] -= 1
          end
        when :jz
          if @registers[args[0]] == 0
            @idx = @idx + args[1]
            next
          else
            # check for any interruptions until its closing jump
            # TODO: states cleanup!
            pipe_index = @idx + 1
            aborted = false
            actions = []
            do_next = false
            look_back = false
            sum_at_jmp = false
            jmp_marker = nil
            until aborted
              piped_instruction = @program.instructions[pipe_index]
              
              case piped_instruction[:op]
              when :jmp
                # check for this jz
                if (piped_instruction[:arg][0] + pipe_index) == @idx || (sum_at_jmp && pipe_index == jmp_marker)
                  iterations = @registers[args[0]]
                  actions.each_index do |i|
                    times = actions[i] || 0
                    @registers[i] += iterations * times
                    if @registers[i] < 0
                      @registers[i] = 0
                    end
                  end
                  @idx = @idx + args[1]
                  aborted = true
                  do_next = true
                  sum_at_jmp = false
                elsif (piped_instruction[:arg][0] + pipe_index) < @idx
                  actions = []
                  jmp_marker = pipe_index
                  pipe_index += piped_instruction[:arg][0]
                  pipe_index -= 1
                  look_back = true
                else
                  aborted = true
                end
              when :halt
                aborted = true
              when :inc
                unless sum_at_jmp
                  register = piped_instruction[:arg][0]
                  actions[register] ||= 0
                  actions[register] += 1
                end
              when :dec
                unless sum_at_jmp
                  register = piped_instruction[:arg][0]
                  actions[register] ||= 0
                  actions[register] -= 1
                end
              when :jz
                if look_back && pipe_index == @idx
                  look_back = false
                  sum_at_jmp = true
                else
                  aborted = true
                end
              end
              pipe_index += 1
            end
            if do_next
              next
            end
          end
        when :jmp
          @idx = @idx + args[0]
          next
        when :halt
          @stopped = true
        else
          errors << "Illegal instruction #{instruction[:op]} at #{@idx}"
          @stopped = true
        end
        
       @idx = @idx + 1
      end
    end
  end
  
  #----------------------------------------------------------------------------
  def self.run(program)
    u = CheatingURM.new(program)
    u.start!
    u.registers
  end
end
