# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CollectionsController, type: :controller do
  let(:valid_attributes) do
    attributes_for(:collection)
  end

  let(:invalid_attributes) do
    {title: ''}
  end

  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET #index' do
    let(:collection) { create(:collection, valid_attributes.merge(users: [user])) }

    it 'assigns all collections as @collections' do
      get :index, params: {}
      expect(assigns(:collections)).to include collection
    end
  end

  describe 'GET #show' do
    let(:collection) { create(:collection, valid_attributes) }

    it 'assigns the requested collection as @collection' do
      get :show, params: {id: collection.to_param}
      expect(assigns(:collection)).to eq(collection)
    end
  end

  describe 'GET #new' do
    it 'assigns a new collection as @collection' do
      get :new, params: {}
      expect(assigns(:collection)).to be_a_new(Collection)
    end
  end

  describe 'GET #edit' do
    let(:collection) { create(:collection, valid_attributes.merge(users: [user])) }

    it 'assigns the requested collection as @collection' do
      get :edit, params: {id: collection.to_param}
      expect(assigns(:collection)).to eq(collection)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new Collection' do
        expect do
          post :create, params: {collection: valid_attributes}
        end.to change(Collection, :count).by(1)
      end

      it 'assigns a newly created collection as @collection' do
        post :create, params: {collection: valid_attributes}
        expect(assigns(:collection)).to be_a(Collection)
      end

      it 'persists @collection' do
        post :create, params: {collection: valid_attributes}
        expect(assigns(:collection)).to be_persisted
      end

      it 'redirects to the created collection' do
        post :create, params: {collection: valid_attributes}
        expect(response).to redirect_to(collections_path)
      end
    end

    context 'with invalid params' do
      it 'assigns a newly created but unsaved collection as @collection' do
        post :create, params: {collection: invalid_attributes}
        expect(assigns(:collection)).to be_a_new(Collection)
      end

      it "re-renders the 'new' template" do
        post :create, params: {collection: invalid_attributes}
        expect(response).to render_template('new')
      end
    end
  end

  describe 'PUT #update' do
    let(:collection) { create(:collection, valid_attributes.merge(users: [user])) }

    context 'with valid params' do
      let(:new_attributes) do
        {title: 'new title'}
      end

      it 'updates the requested collection' do
        expect do
          put :update, params: {id: collection.to_param, collection: new_attributes}
        end.to change { collection.reload.title }.to('new title')
      end

      it 'assigns the requested collection as @collection' do
        put :update, params: {id: collection.to_param, collection: valid_attributes}
        expect(assigns(:collection)).to eq(collection)
      end

      it 'redirects to the collection' do
        put :update, params: {id: collection.to_param, collection: valid_attributes}
        expect(response).to redirect_to(collections_path)
      end
    end

    context 'with invalid params' do
      it 'assigns the collection as @collection' do
        put :update, params: {id: collection.to_param, collection: invalid_attributes}
        expect(assigns(:collection)).to eq(collection)
      end

      it "re-renders the 'edit' template" do
        put :update, params: {id: collection.to_param, collection: invalid_attributes}
        expect(response).to render_template('edit')
      end
    end
  end

  xdescribe 'PATCH #remove_exercise' do
    let(:collection) { create(:collection, valid_attributes.merge(users: [user])) }
    let!(:exercise) { create(:exercise, collections: [collection]) }
    let(:patch_request) { patch :remove_exercise, params: {id: collection.id, exercise: exercise.id} }

    it 'removes exercise from collection' do
      expect { patch_request }.to change(collection.reload.exercises, :count).by(-1)
    end
  end

  xdescribe 'PATCH #remove_all' do
    let(:collection) { create(:collection, valid_attributes.merge(users: [user], exercises: exercises)) }
    let(:exercises) { create_list(:exercise, 2) }

    let(:patch_request) { patch :remove_all, params: {id: collection.id} }

    it 'removes exercise from collection' do
      expect { patch_request }.to change(collection.exercises, :count).by(-2)
    end
  end

  xdescribe 'GET #download_all' do
    let(:collection) { create(:collection, valid_attributes.merge(users: [user], exercises: exercises)) }
    let(:exercises) { create_list(:exercise, 2) }
    let(:zip) { instance_double(StringIO, string: 'dummy') }

    let(:get_request) { get :download_all, params: {id: collection.id} }

    before { allow(ProformaService::ExportTasks).to receive(:call).with(exercises: collection.reload.exercises).and_return(zip) }

    it do
      get_request
      expect(ProformaService::ExportTasks).to have_received(:call)
    end

    it 'updates download count' do
      expect { get_request }.to change { exercises.first.reload.downloads }.by(1)
    end

    it 'sends the correct data' do
      get_request
      expect(response.body).to eql 'dummy'
    end

    it 'sets the correct Content-Type header' do
      get_request
      expect(response.header['Content-Type']).to eql 'application/zip'
    end

    it 'sets the correct Content-Disposition header' do
      get_request
      expect(response.header['Content-Disposition']).to include "attachment; filename=\"#{collection.title}.zip\""
    end
  end

  describe 'POST #share' do
    let(:collection) { create(:collection, valid_attributes.merge(users: [user])) }
    let(:post_request) { post :share, params: params }
    let(:params) { {id: collection.id, user: create(:user).email} }

    it 'creates a message' do
      expect { post_request }.to change(Message, :count).by(1)
    end

    it 'redirects to collection' do
      post_request
      expect(response).to redirect_to collection
    end

    it 'sets flash message' do
      expect(post_request.request.flash[:notice]).to eql I18n.t('controllers.collections.share.notice')
    end

    context 'when no email is given' do
      let(:params) { {id: collection.id} }

      it 'does not create a message' do
        expect { post_request }.not_to change(Message, :count)
      end

      it 'redirects to collection' do
        post_request
        expect(response).to redirect_to collection
      end

      it 'sets flash message' do
        expect(post_request.request.flash[:alert]).to eql I18n.t('controllers.collections.share.alert')
      end
    end
  end

  describe 'POST #view_shared' do
    let(:collection) { create(:collection, valid_attributes.merge(users: [user])) }
    let(:post_request) { post :view_shared, params: params }
    let(:params) { {id: collection.id, user: create(:user).id} }

    it 'assigns collection' do
      post_request
      expect(assigns(:collection)).to eq(collection)
    end

    it 'renders show' do
      post_request
      expect(response).to render_template('show')
    end
  end

  describe 'POST #save_shared' do
    let(:collection) { create(:collection, valid_attributes.merge(users: [create(:user)])) }
    let(:post_request) { post :save_shared, params: params }
    let(:params) { {id: collection.id} }

    it 'increases usercount of collection' do
      expect { post_request }.to change(collection.reload.users, :count).from(1).to(2)
    end

    it 'adds user to collection' do
      post_request
      expect(collection.reload.users).to include user
    end

    it 'redirects to collection' do
      post_request
      expect(response).to redirect_to collection
    end
  end

  describe 'POST #leave' do
    let!(:collection) { create(:collection, valid_attributes.merge(users: users)) }
    let(:users) { [create(:user), user] }
    let(:post_request) { post :leave, params: params }
    let(:params) { {id: collection.id} }

    it 'removes user from collection' do
      post_request
      expect(collection.reload.users).not_to include user
    end

    it 'decreases usercount of collection' do
      expect { post_request }.to change(collection.reload.users, :count).from(2).to(1)
    end

    it 'redirects to the collections list' do
      post_request
      expect(response).to redirect_to(collections_url)
    end

    context 'when there is only one user in collection' do
      let(:users) { [user] }

      it 'deletes collection' do
        expect { post_request }.to change(Collection, :count).by(-1)
      end

      it 'redirects to the collections list' do
        post_request
        expect(response).to redirect_to(collections_url)
      end
    end
  end

  # post push_collection later
  # get collections_all # adminview
end
