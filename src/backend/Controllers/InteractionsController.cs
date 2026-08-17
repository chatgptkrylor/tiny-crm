using System.Web.Mvc;
using Shop.Infrastructure;
using Shop.Models;
using Shop.Repository;

namespace Shop.Controllers
{
    [SessionAuth]
    public class InteractionsController : Controller
    {
        private readonly IInteractionRepository _repo;
        private readonly ICustomerRepository _customerRepo;

        public InteractionsController()
        {
            _repo = new InteractionRepository();
            _customerRepo = new CustomerRepository();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Create(int customerId, string type, string note)
        {
            if (string.IsNullOrEmpty(note))
            {
                TempData["Error"] = "Note cannot be empty.";
                return RedirectToAction("Details", "Customers", new { id = customerId });
            }

            var customer = _customerRepo.GetById(customerId);
            if (customer == null) return HttpNotFound();

            var interaction = new Interaction
            {
                CustomerId = customerId,
                Type = type,
                Note = note,
                LoggedByUserId = (int)Session["UserId"]
            };
            _repo.Create(interaction);
            return RedirectToAction("Details", "Customers", new { id = customerId });
        }
    }
}