# frozen_string_literal: true

require File.join(File.dirname(__FILE__), "evaluation")
require File.join(File.dirname(__FILE__), "trustin")


RSpec.describe TrustIn do
  describe "#update_score" do
    let(:evaluations) { [Evaluation.new(type: "SIREN", value: "832940670", score: 42, state: "unconfirmed", reason: "ongoing_database_update")] }

    subject! { described_class.new(evaluations).update_score }

    context "evaluation is invalid" do 
      it 'raises an error' do 
        expect { Evaluation.new(type: "toto", value: "123456789", score: 2, state: "unconfirmed", reason: "company_closed") }.to raise_error(StandardError)
      end
    end

    context "when the evaluation type is 'SIREN'" do
      context "with a <score> greater or equal to 50 AND the <state> is unconfirmed and the <reason> is 'unable_to_reach_api'" do
        let(:evaluations) { [Evaluation.new(type: "SIREN", value: "123456789", score: 79, state: "unconfirmed", reason: "unable_to_reach_api")] }

        it "decreases the <score> of 5" do
          expect(evaluations.first.score).to eq(74)
        end
      end

      context "when the <state> is unconfirmed and the <reason> is 'unable_to_reach_api'" do
        let(:evaluations) { [Evaluation.new(type: "SIREN", value: "123456789", score: 37, state: "unconfirmed", reason: "unable_to_reach_api")] }

        it "decreases the <score> of 1" do
          expect(evaluations.first.score).to eq(36)
        end
      end

      context "when the <state> is favorable" do
        let(:evaluations) { [Evaluation.new(type: "SIREN", value: "123456789", score: 28, state: "favorable", reason: "company_opened")] }

        it "decreases the <score> of 1" do
          expect(evaluations.first.score).to eq(27)
        end

        
      end

      context "when the <state> is 'unconfirmed' AND the <reason> is 'ongoing_database_update'" do
        let(:evaluations) { [Evaluation.new(type: "SIREN", value: "832940670", score: 42, state: "unconfirmed", reason: "ongoing_database_update")] }
        subject! { described_class.new(evaluations) }

        it "assigns a <state> and a <reason> to the evaluation based on the API response and a <score> to 100" do
          expect(subject).to receive(:api_response).with(evaluations.first.value).and_return(
            {
              'records' => [
                {
                  'fields' => {
                    'etatadministratifetablissement' => 'Actif',
                  }
                }
              ]
            }
          )

          subject.update_score
          expect(evaluations.first.state).to eq("favorable")
          expect(evaluations.first.reason).to eq("company_opened")
          expect(evaluations.first.score).to eq(100)
        end
      end

      context "with a <score> equal to 0" do
        subject! { described_class.new(evaluations) }
        
        let(:evaluations) { [Evaluation.new(type: "SIREN", value: "320878499", score: 0, state: "favorable", reason: "company_opened")] }

        it "assigns a <state> and a <reason> to the evaluation based on the API response and a <score> to 100" do
          subject.update_score

          expect(evaluations.first.state).to eq("unfavorable")
          expect(evaluations.first.reason).to eq("company_closed")
          expect(evaluations.first.score).to eq(100)
        end
      end

      context "with a <state> 'unfavorable'" do
        let(:evaluations) { [Evaluation.new(type: "SIREN", value: "123456789", score: 52, state: "unfavorable", reason: "company_closed")] }

        it "does not decrease its <score>" do
          expect { subject }.not_to change { evaluations.first.score }
        end
      end

      context "with a <state>'unfavorable' AND a <score> equal to 0" do
        let(:evaluations) { [Evaluation.new(type: "SIREN", value: "123456789", score: 0, state: "unfavorable", reason: "company_closed")] }

        it "does not call the API" do
          expect(Net::HTTP).not_to receive(:get)
        end
      end
    end

    context "when the evaluation type is VAT" do 
      let(:evaluations) { [Evaluation.new(type: "VAT", value: "GB727255821", score: 53, state: "unconfirmed", reason: "unable_to_reach_api")] }

      subject! { described_class.new(evaluations) }

      context 'When the state is unconfirmed because the api is unreachable' do 
        context 'if score equal or greater than 50' do 
          it 'decreses of 1' do 
            subject.update_score

            expect(evaluations.first.score).to eq 52
          end
        end

        context 'if score less than 50' do 
          let(:evaluations) { [Evaluation.new(type: "VAT", value: "LU26375245", score: 40, state: "unconfirmed", reason: "unable_to_reach_api")] }

          it 'decreses of 3' do 
            subject.update_score

            expect(evaluations.first.score).to eq 37
          end
        end
      end

      context 'when the state is unconfirmed for an ongoin api update'  do 
        let(:evaluations) { [Evaluation.new(type: "VAT", value: "IE6388047V", score: 40, state: "unconfirmed", reason: "ongoing_database_update")] }
        
        it 'makes the evaluation done' do 
          subject.update_score

          evaluation = evaluations.first

          expect(evaluation.score).to eq 100
          expect(evaluation.state).to eq 'favorable'
          expect(evaluation.reason).to eq 'company_opened'
        end
      end
    end
  end
end
