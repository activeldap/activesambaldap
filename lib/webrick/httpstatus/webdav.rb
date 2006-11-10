require 'webrick/httpstatus'

module WEBrick
  module HTTPStatus
    webdav_status_messages = {
      102, 'Processing',
      207, 'Multi-Status',
      422, 'Unprocessable Entity',
      423, 'Locked',
      424, 'Failed Dependency',
      507, 'Insufficient Storage',
    }
    StatusMessage.each_key {|k| webdav_status_messages.delete(k)}
    StatusMessage.update webdav_status_messages

    webdav_status_messages.each do |code, message|
      var_name = message.gsub(/[ \-]/,'_').upcase
      err_name = message.gsub(/[ \-]/,'')

      case code
      when 100...200; parent = Info
      when 200...300; parent = Success
      when 300...400; parent = Redirect
      when 400...500; parent = ClientError
      when 500...600; parent = ServerError
      end

      eval %-
        RC_#{var_name} = #{code}
        class #{err_name} < #{parent}
          def self.code() RC_#{var_name} end
          def self.reason_phrase() StatusMessage[code] end
          def code() self::class::code end
          def reason_phrase() self::class::reason_phrase end
          alias to_i code
        end
      -

      CodeToError[code] = const_get(err_name)
    end
  end
end
