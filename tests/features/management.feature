@arkmq-org
Feature: Management

  Scenario Outline: Test if management RBAC is <status>
    When container is started with env
      | variable                   | value |
      | AMQ_USER                   | admin |
      | AMQ_PASSWORD               | admin |
      | AMQ_REQUIRE_LOGIN | true |
      | JAVA_OPTS                  | -Dhawtio.roles=admin,guest |
      | AMQ_ENABLE_MANAGEMENT_RBAC | <env value> |
    Then file /home/jboss/broker/etc/management.xml should <management file assert>
    Then check that page is served
        | property | value |
        | username | admin |
        | password | admin |
        | port     | 8161  |
        | path     | /console/jolokia/exec/org.apache.activemq.artemis:broker="broker"/addUser/guest/guest/guest/true |
        | expected_status_code | 200 |
    Then check that page is served
        | property | value |
        | username | guest |
        | password | guest |
        | port     | 8161  |
        | path     | /console/jolokia/read/org.apache.activemq.artemis:broker="broker"/Version |
        | expected_status_code | 200 |
        | expected_phrase | "status":<response status> |
    Examples:
        | status   | env value | response status | management file assert          |
        | enabled  | true      | 403             | not contain <entry domain="*"/> |
        | disabled | false     | 200             | contain <entry domain="*"/>     |
