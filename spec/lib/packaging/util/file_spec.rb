require 'spec_helper'

describe "Pkg::Util::File" do
  let(:source)     { "/tmp/placething.tar.gz" }
  let(:target)     { "/tmp" }
  let(:options)    { "--thing-for-tar" }
  let(:tar)        { "/usr/bin/tar" }
  let(:files)      { ["foo.rb", "foo/bar.rb"] }
  let(:symlinks)   { ["bar.rb"] }
  let(:dirs)       { ["foo"] }
  let(:empty_dirs) { ["bar"] }


  describe "#untar_into" do
    before :each do
      Pkg::Util::Tool.stub(:find_tool).with('tar', :required => true) { tar }
    end

    it "raises an exception if the source doesn't exist" do
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}).and_raise(RuntimeError)
      Pkg::Util::File.should_not_receive(:ex)
      expect { Pkg::Util::File.untar_into(source) }.to raise_error(RuntimeError)
    end

    it "unpacks the tarball to the current directory if no target is passed" do
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}) { true }
      Pkg::Util::File.should_receive(:ex).with("#{tar}   -xf #{source}")
      Pkg::Util::File.untar_into(source)
    end

    it "unpacks the tarball to the current directory with options if no target is passed" do
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}) { true }
      Pkg::Util::File.should_receive(:ex).with("#{tar} #{options}  -xf #{source}")
      Pkg::Util::File.untar_into(source, nil, options)
    end

    it "unpacks the tarball into the target" do
      File.stub(:exist?).with(source) { true }
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}) { true }
      Pkg::Util::File.should_receive(:file_writable?).with(target) { true }
      Pkg::Util::File.should_receive(:ex).with("#{tar}  -C #{target} -xf #{source}")
      Pkg::Util::File.untar_into(source, target)
    end

    it "unpacks the tarball into the target with options passed" do
      File.stub(:exist?).with(source) { true }
      Pkg::Util::File.should_receive(:file_exists?).with(source, {:required => true}) { true }
      Pkg::Util::File.should_receive(:file_writable?).with(target) { true }
      Pkg::Util::File.should_receive(:ex).with("#{tar} #{options} -C #{target} -xf #{source}")
      Pkg::Util::File.untar_into(source, target, options)
    end
  end

  describe "#install_files_into_dir" do
    it "selects the correct files to install" do
      Pkg::Config.load_defaults
      workdir = Pkg::Util::File.mktemp
      patterns = []

      # Set up a bunch of default settings for these to avoid a lot more stubbing in each section below
      File.stub(:file?) { false }
      File.stub(:symlink?) { false }
      File.stub(:directory?) { false }
      Pkg::Util::File.stub(:empty_dir?) { false }

      # Files should have the path made and should be copied
      files.each do |file|
        File.stub(:file?).with(file).and_return(true)
        Dir.stub(:[]).with(file).and_return(file)
        FileUtils.should_receive(:mkpath).with(File.dirname(File.join(workdir, file)), :verbose => false)
        FileUtils.should_receive(:cp).with(file, File.join(workdir, file), :verbose => false, :preserve => true)
        patterns << file
      end

      # Symlinks should have the path made and should be copied
      symlinks.each do |file|
        File.stub(:symlink?).with(file).and_return(true)
        Dir.stub(:[]).with(file).and_return(file)
        FileUtils.should_receive(:mkpath).with(File.dirname(File.join(workdir, file)), :verbose => false)
        FileUtils.should_receive(:cp).with(file, File.join(workdir, file), :verbose => false, :preserve => true)
        patterns << file
      end

      # Dirs should be added to patterns but no acted upon
      dirs.each do |dir|
        File.stub(:directory?).with(dir).and_return(true)
        Dir.stub(:[]).with("#{dir}/**/*").and_return(dir)
        FileUtils.should_not_receive(:mkpath).with(File.dirname(File.join(workdir, dir)), :verbose => false)
        FileUtils.should_not_receive(:cp).with(dir, File.join(workdir, dir), :verbose => false, :preserve => true)
        patterns << dir
      end

      # Empty dirs should have the path created and nothing copied
      empty_dirs.each do |dir|
        Pkg::Util::File.stub(:empty_dir?).with(dir).and_return(true)
        Dir.stub(:[]).with(dir).and_return(dir)
        FileUtils.should_receive(:mkpath).with(File.join(workdir, dir), :verbose => false)
        FileUtils.should_not_receive(:cp).with(dir, File.join(workdir, dir), :verbose => false, :preserve => true)
        patterns << dir
      end

      Pkg::Util::File.install_files_into_dir(patterns, workdir)
      rm_rf workdir
    end
  end
end
