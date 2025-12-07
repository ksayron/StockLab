using StockLab.Services.Interfaces;
using System.Security.Cryptography;
using System.Text;

namespace StockLab.Services.Implementations
{
    public class Md5HashService : IHashService
    {

        private const int DefaultIterations = 10;


        /// <summary>
        /// Высчитывает хеш по 10 итерациям.
        /// </summary>
        public string Hash(string password)
        {
            return Hash(password, DefaultIterations);
        }

        /// <summary>
        /// Высчитывает хеш по заданным итерациям.
        /// </summary>
        public string Hash(string password, int iterations)
        {
            if (string.IsNullOrEmpty(password))
            {
                throw new ArgumentNullException(nameof(password));
            }
            if (iterations <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(iterations), "Iterations must be greater than zero.");
            }

            // Use 'using' for IDisposable resources like MD5
            using var md5 = MD5.Create();

            // Start with the password bytes
            byte[] bytes = Encoding.UTF8.GetBytes(password);

            for (int i = 0; i < iterations; i++)
            {
                // Re-hash the previous hash's byte array
                bytes = md5.ComputeHash(bytes);
            }

            // Convert the final byte array to a hexadecimal string
            var sb = new StringBuilder();
            foreach (byte b in bytes)
            {
                // "x2" formats the byte as a two-digit hexadecimal number
                sb.Append(b.ToString("x2"));
            }

            // MD5 is a 128-bit hash, resulting in a 32-character hex string.
            return sb.ToString();
        }

        public bool IsHashSupported(string hashString)
        {
            if (string.IsNullOrEmpty(hashString))
            {
                return false;
            }

            // MD5 is 128 bits, which is 16 bytes. 
            // 16 bytes converted to hex is 32 characters (16 * 2).
            return hashString.Length == 32 &&
                   // Check if it's a valid hexadecimal string
                   System.Text.RegularExpressions.Regex.IsMatch(hashString, "^[0-9a-fA-F]{32}$");
        }

        public bool Verify(string password, string hashedPassword)
        {
            if (string.IsNullOrEmpty(password) || string.IsNullOrEmpty(hashedPassword))
            {
                return false;
            }

            // Note: This assumes the stored hash was created with the default single iteration.
            // A robust system would store the iteration count with the hash.
            string computedHash = Hash(password, DefaultIterations);

            // Use a case-insensitive comparison for hex strings
            return StringComparer.OrdinalIgnoreCase.Equals(computedHash, hashedPassword);
        }
    }
}
