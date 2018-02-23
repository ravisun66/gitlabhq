require 'spec_helper'

describe Ci::CreateTraceArtifactService do
  describe '#execute' do
    subject { described_class.new(nil, nil).execute(job) }

    context 'when the job does not have trace artifact' do
      context 'when the job has a trace file' do
        let!(:job) { create(:ci_build, :trace_live) }
        let!(:legacy_path) { job.trace.read { |stream| return stream.path } }

        it { expect(File.exists?(legacy_path)).to be_truthy }

        it 'creates trace artifact' do
          expect { subject }.to change { Ci::JobArtifact.count }.by(1)

          expect(File.exists?(legacy_path)).to be_falsy
          expect(File.exists?(job.job_artifacts_trace.file.path)).to be_truthy
          expect(job.job_artifacts_trace.exists?).to be_truthy
          expect(job.job_artifacts_trace.file.filename).to eq('job.log')
        end

        context 'when failed to create trace artifact record' do
          before do
            # When ActiveRecord error happens
            allow_any_instance_of(Ci::JobArtifact).to receive(:save).and_return(false)
            allow_any_instance_of(Ci::JobArtifact).to receive_message_chain(:errors, :full_messages)
              .and_return("Error")

            subject rescue nil

            job.reload
          end

          it 'keeps legacy trace and removes trace artifact' do
            expect(File.exists?(legacy_path)).to be_truthy
            expect(job.job_artifacts_trace).to be_nil
          end
        end
      end

      context 'when the job does not have a trace file' do
        let!(:job) { create(:ci_build) }

        it 'does not create trace artifact' do
          expect { subject }.not_to change { Ci::JobArtifact.count }
        end
      end
    end

    context 'when the job has already had trace artifact' do
      let!(:job) { create(:ci_build, :trace_artifact) }

      it 'does not create trace artifact' do
        expect { subject }.not_to change { Ci::JobArtifact.count }
      end
    end
  end
end
