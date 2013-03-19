module VMC
  module User
    class Base < CLI
      def precondition
        check_logged_in
      end

      private

      def validate_password!(password)
        validate_password_verified!(password)
        # validate_password_strength!(password)
      end
    end
  end
end
