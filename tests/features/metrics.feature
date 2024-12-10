@arkmq-org
Feature: Management

  Scenario Outline: Test if metrics plugin is <status>
    When container is started with env
      | variable                  | value |
      | AMQ_USER                  | admin |
      | AMQ_PASSWORD              | admin |
      | AMQ_ENABLE_METRICS_PLUGIN | <env value> |
    Then file /home/jboss/broker/etc/broker.xml should <file assert>
    Then check that page is served
        | property | value |
        | port     | 8161  |
        | path     | /metrics/ |
        | expected_status_code | <response status> |
    Examples:
        | status   | env value | response status | file assert         |
        | enabled  | true      | 200             | contain metrics     |
        | disabled | false     | 404             | not contain metrics |
