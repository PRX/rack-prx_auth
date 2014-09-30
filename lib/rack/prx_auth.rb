require 'json/jwt'
require 'rack/prx_auth/version'
require 'rack/prx_auth/public_key'

module Rack
  class PrxAuth
    attr_reader :public_key

    def initialize(app)
      @app = app
      @public_key = PublicKey.new
    end

    def call(env)
      if env['HTTP_AUTHORIZATION'] =~ /\ABearer/
        token = env['HTTP_AUTHORIZATION'].split[1]
        claims = JSON::JWT.decode(token, :skip_verification)

        @app.call(env) unless claims['iss'] == 'auth.prx.org'

        if verified?(token) && !token_expired?(claims) && !cert_expired?(@public_key.certificate)
          env['prx.auth'] = claims
          @app.call(env)
        else
          [401, {'Content-Type' => 'application/json'}, [{status: 401, error: 'Invalid JSON Web Token'}.to_json]]
        end
      else
        @app.call(env)
      end
    end

    def verified?(token)
      begin
        JSON::JWT.decode(token, @public_key.key)
      rescue JSON::JWT::VerificationFailed
        false
      else
        true
      end
    end

    def cert_expired?(certificate)
      certificate.not_after < Time.now
    end

    def token_expired?(claims)
      Time.now.to_i > (claims['iat'] + claims['exp'])
    end
  end
end

