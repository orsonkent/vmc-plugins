require 'spec_helper'
require 'manifests-vmc-plugin'

describe VMCManifests do
  let(:cmd) do
    manifest = Object.new
    manifest.extend VMCManifests
    manifest
  end

  describe '#find_apps' do
    subject { cmd.find_apps(nil) }

    context 'when there is no manifest file' do
      before { stub(cmd).manifest { nil } }
      it { should eq [] }
    end
  end
end