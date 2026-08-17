using System;
using System.Collections.Generic;

namespace Shop.Models
{
    public enum CustomerStatus
    {
        Lead = 0,
        Contact = 1,
        Customer = 2
    }

    public enum InteractionType
    {
        Call = 0,
        Email = 1,
        Meeting = 2,
        Note = 3
    }

    public class User
    {
        public int Id { get; set; }
        public string Username { get; set; }
        public string PasswordHash { get; set; }
        public string Role { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class Customer
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string Company { get; set; }
        public string Status { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public int CreatedByUserId { get; set; }
    }

    public class Interaction
    {
        public int Id { get; set; }
        public int CustomerId { get; set; }
        public string Type { get; set; }
        public string Note { get; set; }
        public DateTime LoggedAt { get; set; }
        public int LoggedByUserId { get; set; }
        public string LoggedByUsername { get; set; }
    }

    public class LoginViewModel
    {
        [System.ComponentModel.DataAnnotations.Required(ErrorMessage = "Username is required")]
        public string Username { get; set; }

        [System.ComponentModel.DataAnnotations.Required(ErrorMessage = "Password is required")]
        [System.ComponentModel.DataAnnotations.DataType(System.ComponentModel.DataAnnotations.DataType.Password)]
        public string Password { get; set; }

        public string ReturnUrl { get; set; }
    }

    public class CustomerViewModel
    {
        public int Id { get; set; }

        [System.ComponentModel.DataAnnotations.Required(ErrorMessage = "Name is required")]
        [System.ComponentModel.DataAnnotations.StringLength(100, ErrorMessage = "Name cannot exceed 100 characters")]
        public string Name { get; set; }

        [System.ComponentModel.DataAnnotations.StringLength(100, ErrorMessage = "Email cannot exceed 100 characters")]
        [System.ComponentModel.DataAnnotations.EmailAddress(ErrorMessage = "Invalid email address")]
        public string Email { get; set; }

        [System.ComponentModel.DataAnnotations.StringLength(30, ErrorMessage = "Phone cannot exceed 30 characters")]
        public string Phone { get; set; }

        [System.ComponentModel.DataAnnotations.StringLength(100, ErrorMessage = "Company cannot exceed 100 characters")]
        public string Company { get; set; }

        [System.ComponentModel.DataAnnotations.Required(ErrorMessage = "Status is required")]
        public string Status { get; set; }
    }

    public class InteractionViewModel
    {
        public int CustomerId { get; set; }

        [System.ComponentModel.DataAnnotations.Required(ErrorMessage = "Type is required")]
        public string Type { get; set; }

        [System.ComponentModel.DataAnnotations.Required(ErrorMessage = "Note is required")]
        [System.ComponentModel.DataAnnotations.StringLength(int.MaxValue, MinimumLength = 1, ErrorMessage = "Note cannot be empty")]
        public string Note { get; set; }
    }

    public class DashboardViewModel
    {
        public int TotalCustomers { get; set; }
        public List<StatusCount> StatusCounts { get; set; }
        public List<Interaction> RecentInteractions { get; set; }
        public string Username { get; set; }
    }

    public class StatusCount
    {
        public string Status { get; set; }
        public int Count { get; set; }
    }

    public class ReportViewModel
    {
        public List<StatusCount> StatusCounts { get; set; }
        public int TotalCustomers { get; set; }
    }
}