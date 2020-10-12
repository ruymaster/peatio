class CompactLiabilities < ActiveRecord::Migration[5.2]
  def up_mysql
    execute 'DROP procedure IF EXISTS `compact_orders`;'
    execute <<-SQL

    CREATE PROCEDURE `compact_orders`(
        IN min_date DATETIME,
        IN max_date DATETIME
    )
    BEGIN

        -- Variables
        DECLARE pointer INT;
        DECLARE counter INT;

        -- Temporary liabilities table
        CREATE TABLE IF NOT EXISTS `liabilities_tmp` LIKE `liabilities`;

        -- Copy liabilities to tmp
        INSERT INTO `liabilities_tmp` SELECT * FROM `liabilities`
        WHERE `reference_type` = 'Order' AND `created_at` BETWEEN min_date AND max_date;

        -- Set counter and pointer vars
        SELECT ROW_COUNT() INTO counter;
        SELECT DATE_FORMAT(max_date, "%Y%m%d") INTO pointer;

        -- Delete liabilities to compact
        DELETE FROM `liabilities` WHERE `reference_type` = 'Order' AND `created_at` BETWEEN min_date AND max_date;

        INSERT INTO `liabilities`
        SELECT NULL, code, currency_id, member_id, 'CompactOrders',
        DATE_FORMAT(max_date, "%Y%m%d"), SUM(debit), SUM(credit), DATE(`created_at`), NOW() FROM `liabilities_tmp`
        WHERE `reference_type` = 'Order' AND `created_at` BETWEEN min_date AND max_date
        GROUP BY code, currency_id, member_id, DATE(`created_at`);

        DROP TABLE `liabilities_tmp`;

        -- Return pointer and counter
        SELECT pointer, counter;
    END
    SQL
  end

  def up_postgresql
    execute <<-SQL
    CREATE OR REPLACE FUNCTION compact_orders(
        min_date DATE,
        max_date DATE,
        OUT pointer INTEGER,
        OUT counter INTEGER
    )
    LANGUAGE plpgsql
    AS $$
    BEGIN
        -- Temporary liabilities table
        CREATE TABLE IF NOT EXISTS liabilities_tmp AS TABLE liabilities;

        -- Copy liabilities to tmp
        INSERT INTO liabilities_tmp SELECT * FROM liabilities
        WHERE reference_type = 'Order' AND created_at BETWEEN min_date AND max_date;

        -- Set counter and pointer vars
        SELECT ROW_COUNT() INTO counter;
        SELECT DATE_FORMAT(max_date, "%Y%m%d") INTO pointer;

        -- Delete liabilities to compact
        DELETE FROM liabilities WHERE reference_type = 'Order' AND created_at BETWEEN min_date AND max_date;

        INSERT INTO liabilities
        SELECT NULL, code, currency_id, member_id, 'CompactOrders',
        DATE_FORMAT(max_date, "%Y%m%d"), SUM(debit), SUM(credit), DATE(created_at), NOW() FROM liabilities_tmp
        WHERE reference_type = 'Order' AND created_at BETWEEN min_date AND max_date
        GROUP BY code, currency_id, member_id, DATE(created_at);

        DROP TABLE liabilities_tmp;
    END
    $$;
    SQL
  end

  def up
    case ActiveRecord::Base.connection.adapter_name
    when 'Mysql2'
      up_mysql

    when 'PostgreSQL'
      up_postgresql
    else
      raise "Unsupported adapter: #{ActiveRecord::Base.connection.adapter_name}"
    end

  end

  def down
    execute 'DROP procedure IF EXISTS compact_orders;'
  end
end
