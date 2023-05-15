#/trending
class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy ]
  before_action :checkAdmin, only: %i[ new ]

  def brand
    #rainforest search by brand using the country from the url -> display here with pagination and friendly brand ID
  end

  # GET /products or /products.json
  def index
    @products = Product.all

    @userFound = params['referredBy'].present? ? User.find_by(uuid: params['referredBy']) : nil
    @profile = @userFound.present? ? Stripe::Customer.retrieve(@userFound.stripeCustomerID) : nil
    @membershipDetails = @userFound.present? ? @userFound.checkMembership : nil
  end

  def explore
    @blogs = Blog.all.where(country: params['country']).paginate(page: params['page'], per_page: 8)
    @products = Product.all.where(country: params['country']).paginate(page: params['page'], per_page: 8)
    @callToRain = []

    ahoy.track "Product Page Results", previousPage: request.referrer, currentPage: params['page']
  end

  def amazon
    #analytics
    ahoy.track "Product Purchase Intent", previousPage: request.referrer, asin: params['asin'], referredBy: params['referredBy'].present? ? params['referredBy'] : current_user&.present? ? current_user&.uuid : ENV['usAmazonTag']
    redirect_to User.renderLink(params['referredBy'], params['country'], params['asin'])
  end

  # GET /products/1 or /products/1.json
  def show

    @posts = Blog.where("asins like ?", "%#{params['asin'].upcase}%")
    @profileMetadata = current_user.present? ? Stripe::Customer.retrieve(current_user&.stripeCustomerID)['metadata'] : []
    @callToRain = User.rainforestProduct(@product&.asin, 'us') #.rainforestProduct(asin = nil,search_alias = nil, country = 'us' )


   if params['recommended'].present?
      #analytics
      ahoy.track "Recommended Product Visit", previousPage: request.referrer, asin: params['id'], referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
    else
      #analytics
      ahoy.track "Product Visit", previousPage: request.referrer, asin: params['id'], referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
    end
  end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit
  end

  # POST /products or /products.json
  def create
    @product = Product.new(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to explore_path, notice: "Product was successfully created." }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1 or /products/1.json
  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to product_url(@product), notice: "Product was successfully updated." }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1 or /products/1.json
  def destroy
    @product.destroy

    respond_to do |format|
      format.html { redirect_to products_url, notice: "Product was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.friendly.find_by(asin: params['id'].upcase)
    end

    # Only allow a list of trusted parameters through.
    def product_params
      params.require(:product).permit(:country, :tags, :asin, :referredBy)
    end

    def checkAdmin
      unless current_user&.admin? || current_user&.trustee?
        flash[:error] = "No Access"
        redirect_to root_path
      end
    end
end
