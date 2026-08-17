using System;
using System.Web.Mvc;
using Shop.Infrastructure;
using Shop.Models;
using Shop.Repository;

namespace Shop.Controllers
{
    [SessionAuth]
    public class CustomersController : Controller
    {
        private readonly ICustomerRepository _repo;

        public CustomersController()
        {
            _repo = new CustomerRepository();
        }

        private int PageSize = 10;

        public ActionResult Index(int page = 1)
        {
            var customers = _repo.GetAll(page, PageSize);
            var total = _repo.GetTotalCount();
            ViewBag.CurrentPage = page;
            ViewBag.TotalPages = (int)Math.Ceiling((double)total / PageSize);
            return View(customers);
        }

        [HttpGet]
        public ActionResult Create()
        {
            return View(new CustomerViewModel());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Create(CustomerViewModel model)
        {
            if (!ModelState.IsValid) return View(model);

            var customer = new Customer
            {
                Name = model.Name,
                Email = model.Email,
                Phone = model.Phone,
                Company = model.Company,
                Status = model.Status,
                CreatedByUserId = (int)Session["UserId"]
            };
            _repo.Create(customer);
            return RedirectToAction("Index");
        }

        [HttpGet]
        public ActionResult Edit(int id)
        {
            var c = _repo.GetById(id);
            if (c == null) return HttpNotFound();
            var model = new CustomerViewModel
            {
                Id = c.Id,
                Name = c.Name,
                Email = c.Email,
                Phone = c.Phone,
                Company = c.Company,
                Status = c.Status
            };
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Edit(CustomerViewModel model)
        {
            if (!ModelState.IsValid) return View(model);
            var c = _repo.GetById(model.Id);
            if (c == null) return HttpNotFound();
            c.Name = model.Name;
            c.Email = model.Email;
            c.Phone = model.Phone;
            c.Company = model.Company;
            c.Status = model.Status;
            _repo.Update(c);
            return RedirectToAction("Index");
        }

        public ActionResult Details(int id)
        {
            var c = _repo.GetById(id);
            if (c == null) return HttpNotFound();
            var interactions = new InteractionRepository().GetByCustomerId(id);
            ViewBag.Interactions = interactions;
            return View(c);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Delete(int id)
        {
            _repo.Delete(id);
            return RedirectToAction("Index");
        }
    }
}