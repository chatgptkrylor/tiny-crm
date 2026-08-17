using System.Collections.Generic;
using Shop.Models;

namespace Shop.Repository
{
    public interface IUserRepository
    {
        User GetByUsername(string username);
        User GetById(int id);
    }

    public interface ICustomerRepository
    {
        List<Customer> GetAll(int page, int pageSize);
        int GetTotalCount();
        Customer GetById(int id);
        int Create(Customer customer);
        bool Update(Customer customer);
        bool Delete(int id);
        List<StatusCount> GetCountByStatus();
    }

    public interface IInteractionRepository
    {
        List<Interaction> GetByCustomerId(int customerId);
        List<Interaction> GetRecent(int count);
        int Create(Interaction interaction);
    }
}