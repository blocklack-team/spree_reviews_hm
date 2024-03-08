# frozen_string_literal: true
# app/controllers/spree/api/reviews_controller.rb

module Spree
  module Api
    class ReviewsController < ApplicationController
      before_action :load_product, only: %i[index new create edit update]

      def index
        @reviews = collection
        render json: @reviews.includes([:product, :user, :feedback_reviews])
      end

      def show
        @review = Spree::Review.find(params[:id])
        render json: @review.includes([:product, :user, :feedback_reviews])
      end

      def new
        @review = Spree::Review.new(product: @product)
        authorize! :create, @review
        render json: @review
      end

      def create
        @review = Spree::Review.new(review_params)
        @review.product = @product
        @review.user = spree_current_user if spree_user_signed_in?
        @review.ip_address = request.remote_ip
        @review.locale = I18n.locale.to_s if Spree::Reviews::Config[:track_locale]

        authorize! :create, @review

        if @review.save
          render json: @review, status: :created
        else
          render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def edit
        @review = Spree::Review.find(params[:id])
        if @review.product.nil?
          flash[:error] = I18n.t('spree.error_no_product')
        end
        authorize! :update, @review
    
        render json: @review
      end

      def update
        @review = Spree::Review.find(params[:id])

        authorize! :update, @review

        if @review.update(review_params)
          render json: @review
        else
          render json: { errors: @review.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @review = Spree::Review.find(params[:id])
        authorize! :destroy, @review
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
        %i[rating title review name show_identifier images]
      end

      def review_params
        params.require(:review).permit(permitted_review_attributes)
      end
    end
  end
end
