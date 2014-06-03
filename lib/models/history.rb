module Models::History

  def self.included(base)
    base.send(:extend, InstanceMethods)
    base.instance_eval do
      before_save :create_history
      has_many :histories, -> { order('histories.created_at desc, id desc') }, as: :historiable, dependent: :destroy
      delegate :history_instance, :history_cols, :hstore_cols, to: self

      # class that can manipulate especial histories otherwise it uses
      # an instance of NullHistoryClass
      def history_instance
        @history_instance ||= begin
          return @history_klass.new(history_cols)  if @history_klass.present?
          NullHistoryClass.new
        end
      end

      def history_cols
        @history_cols
      end

      def hstore_cols
        @hstore_cols
      end
    end
  end

  module InstanceMethods
    def has_movement_history(details_col)
      @history_klass = Movements::History.new(details_col)
    end

    # define the class that will be instantiated
    # in the history_instance method
    def has_history_details(klass, *cols)
      @history_klass = klass
      @history_cols = cols
    end

    def has_history_hstore(*cols)
      @hstore_cols = Array(cols)
    end
  end

  private

    # called function in the callback before_save
    def create_history
      if new_record?
        h = store_new_record
      else
        h = store_update
      end
      set_history_extras(h)

      h.all_data = h.all_data.to_json
      h.history_data = h.history_data.to_json

      h.save
    end

    # Stores the class and the to_s attributes of the logged instance
    def set_history_extras(h)
      h.klass_type = self.class.to_s
      h.klass_to_s = self.to_s
    end

    def store_new_record
      histories.build(new_item: true, user_id: history_user_id,
                      historiable_type: self.class.to_s, history_data: {})
    end

    # history_instance is the class used to store extra data for
    # especial history otherwise is instance of NullHistoryClass
    def store_update
      histo = histories.build(
        new_item: false, history_data: get_data,
        historiable_type: self.class.to_s, user_id: history_user_id)
      # Required otherwise it cleans when saving other details ex.(expense_details = true)
      histo.history_data['updated_at'] = {'from' => updated_at, 'to' => DateTime.now, 'type' => 'datetime'}

      history_instance.set_history(self, histo)

      histo
    end

    def get_data(object = self)
      Hash[ get_object_attributes(object).map { |key, val|
        next  if not_changed_or_users?(key)
        get_hash_of_changes(object, key, val)
      }.compact]
    end

    def get_hash_of_changes(object, key, val)
      [key, { 'from' => val, 'to' => object.send(key), 'type' => get_type_for(object, key)} ]
    end

    # Gets the type for normal attribute or hstore
    def get_type_for(object, key)
      if object.class.column_types[key]
        object.class.column_types[key].type
      elsif hstore_cols.any?
        res = hstore_cols.find { |col| object.send(:"hstore_metadata_for_#{col}")[key] }
        if res.is_a?(Hash)
          res[key]
        else
          nil
        end
        #object.respond_to?(:hstore_metadata_for_extras)
        #object.hstore_metadata_for_extras[key.to_sym]
      else
        nil
      end
    end

    def not_changed_or_users?(key)
      changed_users?(key) || send(key) == send(:"#{key}_was")
    end

    def changed_users?(k)
      ['updater_id', 'nuller_id', 'creator_id', 'approver_id'].include?(k.to_s)
    end

    def history_user_id
      UserSession.id
    end

    def get_object_attributes(object)
      object.changed_attributes
    end

    # Null object
    class NullHistoryClass
      def set_history(klass, h); end
    end
end
