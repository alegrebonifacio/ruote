
#
# Testing Ruote (OpenWFEru)
#
# Sun Jun 14 13:33:17 JST 2009
#

require File.join(File.dirname(__FILE__), 'base')


class EftForgetTest < Test::Unit::TestCase
  include FunctionalBase

  def test_basic

    pdef = Ruote.process_definition do
      sequence do
        forget do
          alpha
        end
        alpha
      end
    end

    @engine.register_participant :alpha do
      @tracer << "alpha\n"
    end

    #noisy

    wfid = assert_trace pdef, %w[ alpha alpha ], :sleep => 0.500

    #logger.log.each { |e| puts e['action'] }
    assert_equal 1, logger.log.select { |e| e['action'] == 'ceased' }.size
    assert_equal 1, logger.log.select { |e| e['action'] == 'terminated' }.size
  end

  #def test_variables
  #  pdef = Ruote.process_definition do
  #    set :var => 'a', :value => 0
  #    concurrence do
  #      set :var => 'a', :value => 1
  #      forget do
  #        echo '0_${v:a}'
  #      end
  #      echo '1_${v:a}'
  #    end
  #    echo '2_${v:a}'
  #  end
  #  noisy
  #  assert_trace pdef, %w[ 1_1 0_0 2_1 ]
  #end
end

