require 'rails_helper'

describe HomeController, type: :routing do
  describe 'routing' do
    specify do
      expect(get: '/').to route_to(controller: 'home', action: 'index')
    end

    specify do
      expect(get: '/home/index').to route_to(controller: 'home', action: 'index')
    end
  end
end
