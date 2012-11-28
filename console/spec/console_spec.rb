require "spec_helper"
require "console-vmc-plugin/plugin"

describe "CFConsole" do
  before(:each) do
    @app = mock("app")
    @console = CFConsole.new(nil, @app)
  end

  it "should return connection info for apps that have a console ip and port" do
    instance = mock("instance")
    @app.should_receive(:instances).and_return([instance])
    instance.should_receive(:console).
        and_return({:ip => "192.168.1.1", :port => 3344})

    @console.get_connection_info(nil).
        should == {"hostname" => "192.168.1.1", "port" => 3344}
  end

  it "should raise error when no app instances found" do
    @app.should_receive(:instances).and_return([])

    expect { @console.get_connection_info(nil) }.
        to raise_error("App has no running instances; try starting it.")
  end

  it "should raise error when app does not have console access" do
    instance = mock("instance")
    @app.should_receive(:instances).and_return([instance])
    instance.should_receive(:console).and_return(nil)

    expect { @console.get_connection_info(nil) }.
        to raise_error("App does not have console access; try restarting it.")
  end

  describe "start_console" do
    before(:each) do
      @creds = {
        :path => %w(app cf-rails-console .consoleaccess),
        :yaml => "username: cfuser\npassword: testpw",
        :telnet => {"Name" => "cfuser", "Password" => "testpw"}
      }

      unless example.metadata[:description_args].first ==
          "should raise error if console credentials cannot be obtained"
        @app.should_receive(:file).with(*@creds[:path]).
            and_return(@creds[:yaml])
        @telnet = mock("telnet")
        @console.should_receive(:telnet_client).and_return(@telnet)
      end
    end

    it "should raise error if console credentials cannot be obtained" do
      @app.should_receive(:file).with(*@creds[:path]).
          and_return("username: cfuser")

      expect { @console.start_console }.
          to raise_error("Unable to verify console credentials.")
    end

    it "should raise error if authentication fails" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("Login failed")
      @telnet.should_receive(:close)

      expect { @console.start_console }.to raise_error("Login failed")
    end

    it "should retry authentication on timeout" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_raise(TimeoutError)
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("Switch to inspect mode\nirb():001:0> ")
      verify_console_exit("irb():001:0> ")

      @console.start_console
    end

    it "should retry authentication on EOF" do
      @console.should_receive(:telnet_client).and_return(@telnet)
      @telnet.should_receive(:login).with(@creds[:telnet]).and_raise(EOFError)
      @telnet.should_receive(:close)
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("irb():001:0> ")
      verify_console_exit("irb():001:0> ")

      @console.start_console
    end

    it "should operate console interactively" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("irb():001:0> ")
      Readline.should_receive(:readline).with("irb():001:0> ").
          and_return("puts 'hi'")
      Readline::HISTORY.should_receive(:push).with("puts 'hi'")
      @telnet.should_receive(:cmd).with("puts 'hi'").
          and_return("nil" + "\n" + "irb():002:0> ")
      @console.should_receive(:puts).with("nil")
      verify_console_exit("irb():002:0> ")

      @console.start_console
    end

    it "should not crash if command times out" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("irb():001:0> ")
      Readline.should_receive(:readline).with("irb():001:0> ").
          and_return("puts 'hi'")
      Readline::HISTORY.should_receive(:push).with("puts 'hi'")
      @telnet.should_receive(:cmd).with("puts 'hi'").and_raise(TimeoutError)
      @console.should_receive(:puts).with("Timed out sending command to server.")
      verify_console_exit("irb():001:0> ")

      @console.start_console
    end

    it "should raise error if an EOF is received" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("Switch to inspect mode\nirb():001:0> ")
      Readline.should_receive(:readline).with("irb():001:0> ").
          and_return("puts 'hi'")
      Readline::HISTORY.should_receive(:push).with("puts 'hi'")
      @telnet.should_receive(:cmd).with("puts 'hi'").and_raise(EOFError)

      expect { @console.start_console }.
          to raise_error("The console connection has been terminated. " +
                         "Perhaps the app was stopped or deleted?")
    end

    it "should not keep blank lines in history" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("irb():001:0> ")
      Readline.should_receive(:readline).with("irb():001:0> ").and_return("")
      Readline::HISTORY.should_not_receive(:push).with("")
      @telnet.should_receive(:cmd).with("").and_return("irb():002:0*> ")
      verify_console_exit("irb():002:0*> ")

      @console.start_console
    end

    it "should not keep identical commands in history" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("irb():001:0> ")
      Readline.should_receive(:readline).with("irb():001:0> ").
          and_return("puts 'hi'")
      Readline::HISTORY.should_receive(:to_a).and_return(["puts 'hi'"])
      Readline::HISTORY.should_not_receive(:push).with("puts 'hi'")
      @telnet.should_receive(:cmd).with("puts 'hi'").
          and_return("nil" + "\n" + "irb():002:0> ")
      @console.should_receive(:puts).with("nil")
      verify_console_exit("irb():002:0> ")

      @console.start_console
    end

    it "should return tab completion data" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("Switch to inspect mode\nirb():001:0> ")
      @telnet.should_receive(:cmd).
          with({"String" => "app.\t", "Match" => /\S*\n$/, "Timeout" => 10}).
          and_return("to_s,nil?\n")
      verify_console_exit("irb():001:0> ")

      @console.start_console
      Readline.completion_proc.call("app.").should == ["to_s","nil?"]
    end

    it "should return tab completion data receiving empty completion string" do
       @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("irb():001:0> ")
      @telnet.should_receive(:cmd).
          with({"String" => "app.\t", "Match" => /\S*\n$/, "Timeout" => 10}).
          and_return("\n")
      verify_console_exit("irb():001:0> ")

      @console.start_console
      Readline.completion_proc.call("app.").should == []
    end

    it "should not crash on timeout of remote tab completion data" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("Switch to inspect mode\nirb():001:0> ")
      @telnet.should_receive(:cmd).
          with({"String" => "app.\t", "Match" => /\S*\n$/, "Timeout" => 10}).
          and_raise(TimeoutError)
      verify_console_exit("irb():001:0> ")

      @console.start_console
      Readline.completion_proc.call("app.").should == []
    end

    it "should properly initialize Readline for tab completion" do
      @telnet.should_receive(:login).with(@creds[:telnet]).
          and_return("irb():001:0> ")
      Readline.should_receive(:respond_to?).
          with("basic_word_break_characters=").and_return(true)
      Readline.should_receive(:basic_word_break_characters=).
          with(" \t\n`><=;|&{(")
      Readline.should_receive(:completion_append_character=).with(nil)
      Readline.should_receive(:completion_proc=)
      verify_console_exit("irb():001:0> ")

      @console.start_console
    end
  end

  def verify_console_exit(prompt)
    Readline.should_receive(:readline).with(prompt).and_return("exit")
    @telnet.should_receive(:cmd).with(({"String" => "exit", "Timeout" => 1})).and_raise(TimeoutError)
    @telnet.should_receive(:close)
  end
end
