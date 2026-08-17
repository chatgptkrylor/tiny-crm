using System;
using System.Configuration;
using System.Data.SqlClient;

namespace Shop.Infrastructure
{
    public static class DbConnectionFactory
    {
        public static SqlConnection CreateConnection()
        {
            var connStrings = ConfigurationManager.ConnectionStrings["ShopCRM"];
            var connectionString = connStrings != null ? connStrings.ConnectionString : null;
            if (string.IsNullOrEmpty(connectionString))
                throw new InvalidOperationException("ShopCRM connection string not found in web.config");
            return new SqlConnection(connectionString);
        }
    }
}