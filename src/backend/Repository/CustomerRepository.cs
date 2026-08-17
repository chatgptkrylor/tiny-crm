using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using Shop.Infrastructure;
using Shop.Models;

namespace Shop.Repository
{
    public class CustomerRepository : ICustomerRepository
    {
        public List<Customer> GetAll(int page, int pageSize)
        {
            var customers = new List<Customer>();
            int offset = (page - 1) * pageSize;

            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand(
                    "SELECT Id, Name, Email, Phone, Company, Status, CreatedAt, UpdatedAt, CreatedByUserId " +
                    "FROM dbo.Customers ORDER BY Id OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY", conn))
                {
                    cmd.Parameters.AddWithValue("@Offset", offset);
                    cmd.Parameters.AddWithValue("@PageSize", pageSize);
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            customers.Add(MapCustomer(reader));
                        }
                    }
                }
            }
            return customers;
        }

        public int GetTotalCount()
        {
            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand("SELECT COUNT(*) FROM dbo.Customers", conn))
                {
                    return (int)cmd.ExecuteScalar();
                }
            }
        }

        public Customer GetById(int id)
        {
            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand(
                    "SELECT Id, Name, Email, Phone, Company, Status, CreatedAt, UpdatedAt, CreatedByUserId " +
                    "FROM dbo.Customers WHERE Id = @Id", conn))
                {
                    cmd.Parameters.AddWithValue("@Id", id);
                    using (var reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            return MapCustomer(reader);
                        }
                    }
                }
            }
            return null;
        }

        public int Create(Customer customer)
        {
            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand(
                    "INSERT INTO dbo.Customers (Name, Email, Phone, Company, Status, CreatedByUserId) " +
                    "VALUES (@Name, @Email, @Phone, @Company, @Status, @CreatedByUserId); " +
                    "SELECT CAST(SCOPE_IDENTITY() AS INT);", conn))
                {
                    cmd.Parameters.AddWithValue("@Name", customer.Name);
                    cmd.Parameters.AddWithValue("@Email", (object)customer.Email ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Phone", (object)customer.Phone ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Company", (object)customer.Company ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Status", customer.Status);
                    cmd.Parameters.AddWithValue("@CreatedByUserId", customer.CreatedByUserId);
                    return (int)cmd.ExecuteScalar();
                }
            }
        }

        public bool Update(Customer customer)
        {
            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand(
                    "UPDATE dbo.Customers SET Name = @Name, Email = @Email, Phone = @Phone, " +
                    "Company = @Company, Status = @Status, UpdatedAt = SYSUTCDATETIME() " +
                    "WHERE Id = @Id", conn))
                {
                    cmd.Parameters.AddWithValue("@Id", customer.Id);
                    cmd.Parameters.AddWithValue("@Name", customer.Name);
                    cmd.Parameters.AddWithValue("@Email", (object)customer.Email ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Phone", (object)customer.Phone ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Company", (object)customer.Company ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@Status", customer.Status);
                    return cmd.ExecuteNonQuery() > 0;
                }
            }
        }

        public bool Delete(int id)
        {
            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand("DELETE FROM dbo.Customers WHERE Id = @Id", conn))
                {
                    cmd.Parameters.AddWithValue("@Id", id);
                    return cmd.ExecuteNonQuery() > 0;
                }
            }
        }

        public List<StatusCount> GetCountByStatus()
        {
            var counts = new List<StatusCount>();
            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand(
                    "SELECT Status, COUNT(*) AS Count FROM dbo.Customers GROUP BY Status ORDER BY Status", conn))
                {
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            counts.Add(new StatusCount
                            {
                                Status = (string)reader["Status"],
                                Count = (int)reader["Count"]
                            });
                        }
                    }
                }
            }
            return counts;
        }

        private static Customer MapCustomer(SqlDataReader reader)
        {
            return new Customer
            {
                Id = (int)reader["Id"],
                Name = (string)reader["Name"],
                Email = reader["Email"] as string,
                Phone = reader["Phone"] as string,
                Company = reader["Company"] as string,
                Status = (string)reader["Status"],
                CreatedAt = (DateTime)reader["CreatedAt"],
                UpdatedAt = reader["UpdatedAt"] as DateTime?,
                CreatedByUserId = (int)reader["CreatedByUserId"]
            };
        }
    }
}