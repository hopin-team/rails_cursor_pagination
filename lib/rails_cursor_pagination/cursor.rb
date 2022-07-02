# frozen_string_literal: true

module RailsCursorPagination
  # Cursor class that's used to uniquely identify a record and serialize and
  # deserialize this cursor so that it can be used for pagination. 
  #
  # This class can explicitly be used if you want to paginate without sending
  # the encoded cursor string to the client and want to expose an alternative
  # identifier (like e.g. the ID or a UUID). In that case, the record will first
  # need to be fetched to then generate the cursor needed by this library.
  #
  # Usage:
  #     record = MyModel.find(params[:my_own_id])
  #     cursor = RailsCursorPagination::Cursor.encode(record, :name)
  #     page = RailsCursorPagination::Paginator.new(query, after: cursor).fetch
  #
  class Cursor
    attr_accessor :id, :field, :order_field

    # Generate a cursor for the given record and ordering field. The cursor
    # encodes all the data required to then paginate based on it with the given
    # ordering field.
    #
    # @param record [ActiveRecord]
    #   Model instance for which we want the cursor
    # @param order_field [Symbol]
    #   Column or virtual column of the record that the relation is ordered by
    # @return [String]
    def self.encode(record, order_field)
      new(record.id, order_field, record[order_field]).encode
    end

    # Decode the provided encoded cursor. Returns an instance of this
    # +RailsCursorPagination::Cursor+ class containing either just the cursor's
    # ID or in case of pagination on any other field, containing both the ID and
    # the ordering field value.
    #
    # @param encoded_string [String]
    #   The encoded cursor
    # @param order_field [Symbol]
    #   Optional. The column that is being ordered on in case it's not the ID
    #   column
    # @return [RailsCursorPagination::Cursor]
    def self.decode(encoded_string:, order_field: :id)
      decoded = JSON.parse(Base64.strict_decode64(encoded))
      unless decoded.is_a?(Array)

        if order_field != :id
          raise InvalidCursorError,
                "The given cursor `#{encoded}` was decoded as "\
                "`#{decoded}` but could not be parsed"
        end

        return new(decoded, :id)
      end

      new(decoded[1], order_field, decoded[0])
    rescue ArgumentError, JSON::ParserError
      raise InvalidCursorError,
            "The given cursor `#{@cursor.inspect}` could not be decoded"
    end

    # Initializes the record
    #
    # @param id [Integer]
    #   The ID of the cursor record
    # @param order_field [Symbol]
    #   The column or virtual column for ordering
    # @param field [Object]
    #   Optional. The value that the +order_field+ of the record contains in
    #   case that the order field is not the ID
    def initialize(id, order_field, field = nil)
      @id = id
      @order_field = order_field
      @field = field
    end

    # Generate an encoded string for this cursor. The cursor encodes all the
    # data required to then paginate based on it with the given ordering field.
    #
    # If we only order by ID, the cursor doesn't need to include any other data.
    # But if we order by any other field, the cursor needs to include both the
    # value from this other field as well as the records ID to resolve the order
    # of duplicates in the non-ID field.
    #
    # @return [String]
    def encode
      unencoded_cursor =
        if custom_order_field?
          [@field, @id]
        else
          @id
        end
      Base64.strict_encode64(unencoded_cursor.to_json)
    end

    private

    # Returns true when the order has been overridden from the default (ID)
    #
    # @return [Boolean]
    def custom_order_field?
      @order_field != :id
    end
  end
end