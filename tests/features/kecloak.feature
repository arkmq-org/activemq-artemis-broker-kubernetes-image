@arkmq-org
Feature: Keycloak

  Scenario: Test keycloak artifacts
    When container is started with env
      | variable                   | value |
      | AMQ_USER                   | admin |
      | AMQ_PASSWORD               | admin |
    Then run ls -al /opt/amq/lib/ in container and immediately check its output for keycloak
