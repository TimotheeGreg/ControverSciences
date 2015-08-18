class UsersController < ApplicationController
  before_action :logged_in_user, only: [:edit, :update, :destroy]
  before_action :correct_user,   only: [:edit, :update]
  before_action :admin_user,     only: [:destroy]

  def new
    @user = User.new
  end

  def checkemail
    mydomain = params[:user].partition("@")[2]
    Domain.all.pluck(:name).each do |domain|
      if mydomain.include? domain
        render :nothing => true, :status => 200
        return true
      end
    end
    render :nothing => true, :status => 409
  end

  def index
    @users = User.includes(:user_detail).where( activated: true ).order(score: :desc ).page(params[:page]).per(24)
  end

  def show
    begin
      @user = User.find(params[:id])
      @user_detail = @user.user_detail
      @timelines = Timeline.includes(:tags).select(:id, :slug, :name).where(user_id: @user.id).where.not(private: true)
      @references = Reference.select(:id, :slug, :timeline_id, :title).where(user_id: @user.id)
      @comments = Comment.select(:id, :reference_id, :title_markdown ).where(user_id: @user.id).where(public: true)
      @summaries = Summary.select(:id, :timeline_id, :content ).where(user_id: @user.id).where(public: true)
    rescue ActiveRecord::RecordNotFound
      flash[:danger] = "Aucun contributeur à ce lien ;-("
      redirect_to users_path
    end
  end

  def edit
    @user = User.find(params[:id])
    @user_detail = UserDetail.find_by_user_id( params[:id] )
    unless @user_detail
      @user_detail = UserDetail.new( user_id: params[:id] )
      @user_detail.send_email = true
    end
  end

  def create
    @user = User.new(user_params)
    if @user.save
      if logged_in?
        @my_likes = Like.where(user_id: current_user.id).pluck( :timeline_id )
      end
      if logged_in?
        @my_likes = Like.where(user_id: current_user.id).pluck( :timeline_id )
      end
      @timelines = Timeline.order(:score => :desc).first(8)
      if @user.invalid_email
        PendingUser.create( user_id: @user.id, why: user_params[:why])
        render 'users/invalid'
      else
        mg_client = Mailgun::Client.new ENV['MAILGUN_CS_API']
        message = {
            :subject=> "Activation du compte sur ControverSciences",
            :from=>"activation@controversciences.org",
            :to => @user.email,
            :html => render_to_string( :file => 'user_mailer/account_activation', layout: nil ).to_str
        }
        mg_client.send_message "controversciences.org", message
        render 'users/success'
      end
    else
      render 'new'
    end
  end

  def update
    @user = User.find(params[:id])
    if @user.update(user_params)
      flash[:success] = "Les modifications apportées à votre profil ont été enregistrées."
      redirect_to @user
    else
      @user_detail = UserDetail.find_by_user_id( params[:id] )
      unless @user_detail
        @user_detail = UserDetail.new( user_id: params[:id] )
        @user_detail.send_email = true
      end
      render 'edit'
    end
  end

  def switch_admin
    if current_user.can_switch_admin
      if current_user.admin
        current_user.update_columns(admin: false)
      else
        current_user.update_columns(admin: true)
      end
    end
    redirect_to :back
  end

  def slack
    Slack.configure do |config|
      config.token = ENV['SLACK_API_TOKEN']
    end
    client = Slack::Web::Client.new

    if client.auth_test
      if client.users_list["members"].index{ |user| user["profile"]["email"] == current_user.email }.blank?
        if ["ens-lyon.fr","umontpellier.fr","controversciences.org","univ-montp2.fr"].include? current_user.email.partition("@")[2]
          redirect_to "https://controversciences.slack.com/signup"
        else
          begin
            client.post('users.admin.invite', {email: current_user.email, set_active: true })
            flash[:success] = "Votre invitation a été envoyé à l'adresse #{current_user.email} !"
            redirect_to current_user
          rescue
            admin_group = client.groups_list['groups'].detect { |c| c['name'] == 'admins' }
            client.chat_postMessage(channel: admin_group['id'], text: "#{current_user.email} invitation needs to be resent !")
            flash[:danger] = "Vous avez deja reçu l'invitation de Slack à l'adresse #{current_user.email}, mais vous n'avez pas encore activé votre compte.
                                Veuillez contacter admin@controversciences.org si vous ne trouvez pas cet email"
            redirect_to current_user
          end
        end
      else
        redirect_to "https://controversciences.slack.com/signin"
      end
    else
      flash[:danger] = "Le serveur n'a pas pu se connecter à Slack"
      redirect_to current_user
    end
  end

  def destroy
    User.find(params[:id]).destroy
    flash[:success] = "Utilisateur destroyed"
    redirect_to users_url
  end

  def previous
    users = User.select(:id, :slug, :score).order(score: :desc).where( activated: true )
    i = users.index{|x| x.id == params[:id].to_i }
    if i == 0
      i = users.length-1
    else
      i-=1
    end
    redirect_to user_path(users[i])
  end

  def next
    users = User.select(:id, :slug, :score).order(score: :desc).where( activated: true )
    i = users.index{|x| x.id == params[:id].to_i }
    if i == users.length-1
      i = 0
    else
      i += 1
    end
    redirect_to user_path(users[i])
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password,
                                 :password_confirmation, :why, :terms_of_service)
  end

  def user_detail_params
    params.require(:user_detail).permit(:user_id, :biography, :picture)
  end
end
