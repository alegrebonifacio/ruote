#
#--
# Copyright (c) 2007-2008, John Mettraux, OpenWFE.org
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# . Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# . Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# . Neither the name of the "OpenWFE" nor the names of its contributors may be
#   used to endorse or promote products derived from this software without
#   specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#++
#

#
# "made in Japan"
#
# John Mettraux at openwfe.org
#

require 'openwfe/service'
require 'openwfe/omixins'
require 'openwfe/rudefinitions'


module OpenWFE

  #
  # A Mixin for history modules
  #
  module HistoryMixin
    include ServiceMixin
    include OwfeServiceLocator

    EXPOOL_EVENTS = [
      :launch, # launching of a [sub]process instance
      :terminate, # process instance terminates
      :cancel, # cancelling an expression
      :error,
      :reschedule, # at restart, engine reschedules a timed expression
      :stop, # stopping the process engine
      :pause, # pausing a process
      :resume, # resuming a process
      #:launch_child, # launching a process 'fragment'
      #:launch_orphan, # firing and forgetting a sub process
      #:forget, # forgetting an expression (making it an orphan)
      #:remove, # removing an expression
      #:update, # expression changed, reinsertion into storage
      #:apply,
      #:reply,
      #:reply_to_parent, # expression replies to its parent expression
    ]

    def service_init (service_name, application_context)

      super

      get_expression_pool.add_observer(:all) do |event, *args|
        handle :expool, event, *args
      end
      get_participant_map.add_observer(:all) do |event, *args|
        handle :pmap, event, *args
      end
    end

    #
    # filter events, eventually logs them
    #
    def handle (source, event, *args)

      # filtering expool events

      return if source == :expool and (not EXPOOL_EVENTS.include?(event))

      # normalizing pmap events

      return if source == :pmap and args.first == :after_consume

      if source == :pmap and (not event.is_a?(Symbol))
        return if args.first == :apply
        e = event
        event = args.first
        args[0] = e
      end
        # have to do that swap has pmap uses the participant name as
        # a "channel name"

      # ok, do log now

      log source, event, *args
    end

    #
    # the logging job itself
    #
    def log (source, event, *args)

      raise NotImplementedError.new(
        "please provide an implementation of log(source, event, *args)")
    end

    #
    # scans the arguments of the event to determine the fei
    # (flow expression id) related to the event
    #
    def get_fei (args)

      args.each do |a|
        return a.fei if a.respond_to?(:fei)
        return a if a.is_a?(FlowExpressionId)
      end

      nil
    end

    #
    # builds a 'message' string out of the event / args combination
    #
    def get_message (source, event, args)

      args.inject([]) { |r, a|
        r << a if a.is_a?(Symbol) or a.is_a?(String)
        r
      }.join(" ")
    end

    #
    # returns the workitem among the logged args
    #
    def get_workitem (args)

      args.find { |a| a.is_a?(WorkItem) }
    end
  end

  #
  # A base implementation for InMemoryHistory and FileHistory.
  #
  class History
    include HistoryMixin

    def initialize (service_name, application_context)

      super()

      service_init(service_name, application_context)
    end

    def log (source, event, *args)

      t = Time.now

      msg = "#{t} .#{t.usec} -- #{source.to_s} #{event.to_s}"

      msg << " #{get_fei(args).to_s}" if args.length > 0

      m = get_message(source, event, args)
      msg << " #{m}" if m

      @output << msg + "\n"
    end
  end

  #
  # The simplest implementation, stores the latest 1000 history
  # entries in memory.
  #
  class InMemoryHistory < History

    #
    # the max number of history items stored. By default it's 1000
    #
    attr_accessor :maxsize

    def initialize (service_name, application_context)

      super

      @output = []
      @maxsize = 1008
    end

    #
    # Returns the array of entries.
    #
    def entries
      @output
    end

    def log (source, event, *args)

      super

      while @output.size > @maxsize
        @output.shift
      end
    end

    #
    # Returns all the entries as a String.
    #
    def to_s
      @output.inject("") { |r, entry| r << entry.to_s }
    end
  end

  #
  # Simply dumps the history in the work directory in a file named
  # "history.log"
  # Warning : no fancy rotation or compression implemented here.
  #
  class FileHistory < History

    def initialize (service_name, application_context)

      super

      @output = get_work_directory + '/history.log'
      @output = File.open(@output, 'w+')

      linfo { "new() outputting history to #{@output.path}" }
    end

    def log (source, event, *args)

      super unless @output.closed?
    end

    #
    # Returns a handle on the output file instance used by this
    # FileHistory.
    #
    def output_file
      @output
    end

    def stop
      @output.close
    end
  end

end

