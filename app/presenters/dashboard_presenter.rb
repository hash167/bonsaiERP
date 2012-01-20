# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
class DashboardPresenter < BasePresenter

  def change_password_link
    if current_user.change_default_password?
      h.content_tag(:h3, h.link_to("Advertencia! debe cambiar su contraseña", h.default_password_users_path, :class => 'red' ) )
    end
  end

  def create_money_link
    unless MoneyStore.any?
      content_tag(:h3, "Por favor le recomendamos crear una #{h.link_to "cuenta bancaria", h.new_bank_path } o #{h.link_to "cuenta de caja", h.new_cash_path}".html_safe)
    end
  end

  # Return the total of bank or 
  def total_money(type)
    return false unless [:bank, :cash].include?(type)

    Account.send(type).group(:currency_id).sum(:amount).map do |cur_id, amt|
      [currencies[cur_id], amt]
    end
  end

  def money(type = :bank)
    Account.send(type).order(:name).values_of(:accountable_id, :currency_id, :name, :amount).map do |id, cur, name, amt|
      {:id => id, :currency => currencies[cur], :name => name, :amount => amt}
    end
  end

  def banks
    money(:bank)
  end

  def cashes
    money(:cash)
  end

  def accounts_to_recieve
    tot_accounts = Account.to_recieve.group(:currency_id).sum(:amount)
    tot_incomes  = Income.approved.group(:currency_id).sum(:balance)
    keys = (tot_accounts.keys + tot_incomes.keys).uniq
  
    keys.map do |cur_id|
      s = tot_accounts[cur_id].to_f.abs + tot_incomes[cur_id].to_f
      [currencies[cur_id], s]
    end
  end

  def currencies
    @currencies ||= Hash[Currency.scoped.values_of(:id, :symbol)]
  end

  def accounts_to_pay
    tot_accounts = Account.to_pay.group(:currency_id).sum(:amount)
    tot_incomes  = Buy.approved.group(:currency_id).sum(:balance)
    keys = (tot_accounts.keys + tot_incomes.keys).uniq
  
    keys.map do |cur_id|
      s = tot_accounts[cur_id].to_f.abs + tot_incomes[cur_id].to_f
      [currencies[cur_id], s]
    end
  end

  def pendent_conciliations
    AccountLedger.pendent.includes(:account).map do |al|
      [currencies[al.currency_id], al, al.account.to_s]
    end
  end

  def minimum_inventory
    @min_list ||= Stock.minimum_list
    @stores   ||= Hash[Store.where(:id => @min_list.keys).values_of(:id, :name)]
    @list     ||= @min_list.map {|k, v| [k, @stores[k], v]}
  end

  def minimum_list
    @min_list ||= Stock.minimum_list
  end

  def due_date
    if h.session[:organisation][:due_date] + 5.days < Date.today
      h.content_tag(:h3, "Estimado cliente su cuenta ha expirado, por favor realice el pago correspondiente contactandose a <span class='black b'>contacto@bonsaierp.com</span>".html_safe, 
                    :class => 'n', :style => 'background-color:#FFCCFF; padding: 8px; border: 2px solid #FF0000')
    end
  end
end
