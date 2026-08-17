using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using Shop.Infrastructure;
using Shop.Models;

namespace Shop.Repository
{
    public class InteractionRepository : IInteractionRepository
    {
        public List<Interaction> GetByCustomerId(int customerId)
        {
            var interactions = new List<Interaction>();
            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand(
                    "SELECT i.Id, i.CustomerId, i.Type, i.Note, i.LoggedAt, i.LoggedByUserId, u.Username AS LoggedByUsername " +
                    "FROM dbo.Interactions i " +
                    "INNER JOIN dbo.Users u ON i.LoggedByUserId = u.Id " +
                    "WHERE i.CustomerId = @CustomerId " +
                    "ORDER BY i.LoggedAt DESC", conn))
                {
                    cmd.Parameters.AddWithValue("@CustomerId", customerId);
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            interactions.Add(MapInteraction(reader));
                        }
                    }
                }
            }
            return interactions;
        }

        public List<Interaction> GetRecent(int count)
        {
            var interactions = new List<Interaction>();
            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand(
                    "SELECT TOP (@Count) i.Id, i.CustomerId, i.Type, i.Note, i.LoggedAt, i.LoggedByUserId, u.Username AS LoggedByUsername " +
                    "FROM dbo.Interactions i " +
                    "INNER JOIN dbo.Users u ON i.LoggedByUserId = u.Id " +
                    "ORDER BY i.LoggedAt DESC", conn))
                {
                    cmd.Parameters.AddWithValue("@Count", count);
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            interactions.Add(MapInteraction(reader));
                        }
                    }
                }
            }
            return interactions;
        }

        public int Create(Interaction interaction)
        {
            using (var conn = DbConnectionFactory.CreateConnection())
            {
                conn.Open();
                using (var cmd = new SqlCommand(
                    "INSERT INTO dbo.Interactions (CustomerId, Type, Note, LoggedByUserId) " +
                    "VALUES (@CustomerId, @Type, @Note, @LoggedByUserId); " +
                    "SELECT CAST(SCOPE_IDENTITY() AS INT);", conn))
                {
                    cmd.Parameters.AddWithValue("@CustomerId", interaction.CustomerId);
                    cmd.Parameters.AddWithValue("@Type", interaction.Type);
                    cmd.Parameters.AddWithValue("@Note", interaction.Note);
                    cmd.Parameters.AddWithValue("@LoggedByUserId", interaction.LoggedByUserId);
                    return (int)cmd.ExecuteScalar();
                }
            }
        }

        private static Interaction MapInteraction(SqlDataReader reader)
        {
            return new Interaction
            {
                Id = (int)reader["Id"],
                CustomerId = (int)reader["CustomerId"],
                Type = (string)reader["Type"],
                Note = (string)reader["Note"],
                LoggedAt = (DateTime)reader["LoggedAt"],
                LoggedByUserId = (int)reader["LoggedByUserId"],
                LoggedByUsername = (string)reader["LoggedByUsername"]
            };
        }
    }
}