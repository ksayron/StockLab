using FluentValidation;
using StockLab.Models.DTOs;

namespace StockLab.Services.Validation
{
    public class RegisterRequestValidator : AbstractValidator<RegisterRequest>
    {
        public RegisterRequestValidator()
        {
            RuleFor(x => x.Username).NotEmpty().MinimumLength(3);
            RuleFor(x => x.Email).EmailAddress();
            RuleFor(x => x.PasswordHash).NotEmpty();
        }   
    }
}
