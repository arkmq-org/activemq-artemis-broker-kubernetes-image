@arkmq-org
Feature: Scaledown

  Scenario: Test if DRAINER_HOST works
    When container is started with command /opt/amq/bin/drain.sh
      | variable     | value       |
      | DRAINER_HOST   | 10.1.233.13 |
    Then available container log should contain 10.1.233.13

  Scenario: Test if DRAINER_HOST is absent
    When container is started with command /opt/amq/bin/drain.sh
    Then available container log should contain DRAINER_HOST is not set
