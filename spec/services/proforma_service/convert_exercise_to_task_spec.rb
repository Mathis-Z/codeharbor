# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProformaService::ConvertExerciseToTask do
  describe '.new' do
    subject(:convert_to_task) { described_class.new(exercise: exercise) }

    let(:exercise) { build(:exercise) }

    it 'assigns exercise' do
      expect(convert_to_task.instance_variable_get(:@exercise)).to be exercise
    end
  end

  describe '#execute' do
    subject(:task) { convert_to_task.execute }

    let(:convert_to_task) { described_class.new(exercise: exercise) }
    let(:exercise) { create(:exercise, instruction: 'instruction', uuid: SecureRandom.uuid, exercise_files: files, tests: tests) }
    let(:files) { [] }
    let(:tests) { [] }

    it 'creates a task with all basic attributes' do
      expect(task).to have_attributes(
        title: exercise.title,
        description: Kramdown::Document.new(exercise.descriptions.select(&:primary?).first.text).to_html.strip,
        internal_description: exercise.instruction,
        proglang: {
          name: exercise.execution_environment.language,
          version: exercise.execution_environment.version
        },
        uuid: exercise.uuid,
        language: exercise.descriptions.select(&:primary?).first.language,
        parent_uuid: exercise.clone_relations.first&.origin&.uuid,
        files: [],
        tests: [],
        model_solutions: []
      )
    end

    context 'with options' do
      let(:convert_to_task) { described_class.new(exercise: exercise, options: options) }
      let(:options) {{}} # TODO descriptions

    end

    context 'when exercise has a mainfile' do
      let(:files) { [file] }
      let(:file) { build(:codeharbor_main_file) }

      it 'creates a task-file with the correct attributes' do
        expect(task.files.first).to have_attributes(
          id: file.id,
          content: file.content,
          filename: file.full_file_name,
          used_by_grader: true,
          usage_by_lms: 'edit',
          visible: 'yes',
          binary: false,
          internal_description: 'main_file'
        )
      end
    end

    context 'when exercise has a regular file' do
      let(:files) { [file] }
      let(:file) { build(:codeharbor_regular_file) }

      it 'creates a task-file with the correct attributes' do
        expect(task.files.first).to have_attributes(
          id: file.id,
          content: file.content,
          filename: file.full_file_name,
          used_by_grader: true,
          usage_by_lms: 'display',
          visible: 'no',
          binary: false,
          internal_description: 'regular_file'
        )
      end

      context 'when file is not hidden' do
        let(:file) { build(:codeharbor_regular_file, hidden: false) }

        it 'creates a task-file with the correct attributes' do
          expect(task.files.first).to have_attributes(visible: 'yes')
        end
      end

      context 'when file is not read_only' do
        let(:file) { build(:codeharbor_regular_file, read_only: false) }

        it 'creates a task-file with the correct attributes' do
          expect(task.files.first).to have_attributes(usage_by_lms: 'edit')
        end
      end

      context 'when file has an attachment' do
        let(:file) { build(:codeharbor_regular_file, :with_attachment) }

        it 'creates a task-file with the correct attributes' do
          expect(task.files.first).to have_attributes(
            used_by_grader: false,
            binary: true,
            mimetype: 'image/bmp'
          )
        end
      end
    end

    context 'when exercise has a file with role reference implementation' do
      let(:files) { [file] }
      let(:file) { build(:codeharbor_solution_file) }

      it 'creates a task with one model-solution' do
        expect(task.model_solutions).to have(1).item
      end

      it 'creates a model-solution with one file' do
        expect(task.model_solutions.first).to have_attributes(
          id: "ms-#{file.id}",
          files: have(1).item
        )
      end

      it 'creates a model-solution with one file with correct attributes' do
        expect(task.model_solutions.first.files.first).to have_attributes(
          id: file.id,
          content: file.content,
          filename: file.full_file_name,
          used_by_grader: false,
          usage_by_lms: 'display',
          visible: 'yes',
          binary: false,
          internal_description: 'reference_implementation'
        )
      end
    end

    context 'when exercise has multiple files with role reference implementation' do
      let(:files) { build_list(:codeharbor_solution_file, 2) }

      it 'creates a task with two model-solutions' do
        expect(task.model_solutions).to have(2).items
      end
    end

    context 'when exercise has a test' do
      let(:tests) { [test] }
      let(:test) { build(:codeharbor_test, exercise_file: file) }
      let(:file) { build(:codeharbor_test_file) }

      it 'creates a task with one test' do
        expect(task.tests).to have(1).item
      end

      it 'creates a test with correct attributes and one file' do
        expect(task.tests.first).to have_attributes(
          id: test.id,
          title: file.name,
          files: have(1).item,
          configuration: {
            'entry-point' => file.full_file_name,
            'framework' => test.testing_framework.name,
            'version' => test.testing_framework.version
          },
          meta_data: {
            'feedback-message' => test.feedback_message,
            'testing-framework' => test.testing_framework.name,
            'testing-framework-version' => test.testing_framework.version
          }
        )
      end

      it 'creates a test with one file with correct attributes' do
        expect(task.tests.first.files.first).to have_attributes(
          id: file.id,
          content: file.content,
          filename: file.full_file_name,
          used_by_grader: true,
          visible: 'no',
          binary: false,
          internal_description: 'teacher_defined_test'
        )
      end

      context 'when exercise_file is not hidden' do
        let(:file) { build(:codeharbor_test_file, hidden: false) }

        it 'creates the test file with the correct attribute' do
          expect(task.tests.first.files.first).to have_attributes(visible: 'yes')
        end
      end

      context 'when exercise_file has a custom role' do
        let(:file) { build(:codeharbor_test_file, role: 'Very important test') }

        it 'creates the test file with the correct attribute' do
          expect(task.tests.first.files.first).to have_attributes(internal_description: 'Very important test')
        end
      end

      context 'when test has no testing_framework and feedback_message' do
        let(:test) { build(:codeharbor_test, feedback_message: nil, testing_framework: nil) }

        it 'does not add feedback_message to meta_data' do
          expect(task.tests.first).to have_attributes(meta_data: {})
        end
      end
    end

    context 'when exercise has multiple tests' do
      let(:tests) { build_list(:codeharbor_test, 2) }

      it 'creates a task with two tests' do
        expect(task.tests).to have(2).items
      end
    end

    context 'when exercise has description formatted in markdown' do
      let(:exercise) { create(:exercise, descriptions: [build(:description, :primary, text: description, language: 'de')]) }
      let(:description) { '# H1 header' }

      it 'creates a task with description and language from primary description' do
        expect(task).to have_attributes(description: '<h1 id="h1-header">H1 header</h1>')
      end
    end

    context 'when exercise has multiple descriptions' do
      let(:exercise) do
        create(:exercise,
               descriptions: [
                 build(:description, text: 'desc', language: 'de'),
                 build(:description, text: 'other dec', language: 'ja'),
                 build(:description, :primary, text: 'primary desc', language: 'en')
               ])
      end

      it 'creates a task with description and language from primary description' do
        expect(task).to have_attributes(
          description: '<p>primary desc</p>',
          language: 'en'
        )
      end
    end
  end
end
