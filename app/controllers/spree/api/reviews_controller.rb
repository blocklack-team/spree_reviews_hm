# frozen_string_literal: true
# app/controllers/spree/api/reviews_controller.rb

module Spree
  module Api
    class ReviewsController < ::Spree::Api::V2::ResourceController
      before_action :require_spree_current_user, except: %i[index]

      before_action :load_product, :find_review_user
      before_action :load_review, only: [:show, :update, :destroy]
      before_action :sanitize_rating, only: [:create, :update]
      before_action :prevent_multiple_reviews, only: [:create]

      def index
        @reviews = Spree::Review.includes([:product, :user, :feedback_reviews]).where(product_id: params[:product_id])
        total_reviews = @reviews.size
        average_rating = total_reviews > 0 ? @reviews.sum(:rating).to_f / total_reviews : 0

        render json: {
          reviews: @reviews.as_json(include: { product: { only: [:id, :name] }, user: { only: [:id, :first_name, :last_name] } }),
          total_reviews: total_reviews,
          average: average_rating.round
        }
      end

      def show
        @review = Spree::Review.includes([:product, :user, :feedback_reviews]).find(params[:id])
        render json: @review.as_json(include: { product: { only: [:id, :name] }, user: { only: [:id, :first_name, :last_name] } })
      end

      def new
        @review = Spree::Review.new(product: @product)
        spree_authorize! :create, spree_current_user
        render json: @review
      end

      def create
        @review = Spree::Review.new(review_params)
        @review.product = @product
        @review.user = spree_current_user if spree_user_signed_in?
        @review.ip_address = request.remote_ip
        @review.locale = I18n.locale.to_s if Spree::Reviews::Config[:track_locale]

        if @review.save
          render json: @review, status: :created
          return
        else
          render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
          return
        end
      end

      def edit
        @review = Spree::Review.find(params[:id])
        if @review.product.nil?
          flash[:error] = I18n.t('spree.error_no_product')
        end

        spree_authorize! :update, spree_current_user
    
        render json: @review
      end

      def update
        @review = Spree::Review.find(params[:id])

        spree_authorize! :update, spree_current_user

        if @review.update(review_params)
          render json: @review
        else
          render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @review = Spree::Review.find(params[:id])
        spree_authorize! :destroy, spree_current_user
        @review.destroy
        head :no_content
      end

      private

      def collection
        params[:q] ||= {}
        @search = Spree::Review.ransack(params[:q])
        @collection = @search.result.includes([:product, :user, :feedback_reviews])
      end

      def load_product
        @product = Spree::Product.friendly.find(params[:product_id])
      end

      def permitted_review_attributes
        [:product_id, :user_id, :rating, :title, :review, :name, :show_identifier]
      end

      def review_params
        params.permit(permitted_review_attributes)
      end

      def load_review
        @review = Spree::Review.find(params[:id])
      end

      # Finds user based on api_key or by user_id if api_key belongs to an admin.
      def find_review_user
        if spree_current_user.present?
          @current_api_user = Spree.user_class.find_by(id: spree_current_user)
          raise "User not found for current user ID: #{spree_current_user}" unless @current_api_user
        else
          raise "No current user found"
        end
      end

      # Ensures that a user can't create more than 1 review per product
      def prevent_multiple_reviews
        @review = @current_api_user.reviews.find_by(product: @product)
        if @review.present?
          render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Converts rating strings like "5 units" to "5"
      # Operates on params
      def sanitize_rating
        params[:rating].sub!(/\s*[^0-9]*\z/, '') if params[:rating].present?
      end
    end
  end
end
