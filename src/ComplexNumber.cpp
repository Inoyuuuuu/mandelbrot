#include <cmath>
struct ComplexNumber
{
    double real;
    double imag;

    public:
        ComplexNumber(double r, double i) : real(r), imag(i) {}

        double absoluteValueSquared() {
            return this->real*this->real + this->imag*this->imag;
        }

        double absoluteValue() {
            return sqrt(this->absoluteValueSquared());
        }

        ComplexNumber& operator=(const ComplexNumber& b) {
            if (this == &b) {
                return *this;
            }

            this->real = b.real;
            this->imag = b.imag;

            return *this;
        }

        void print() {
            std::cout << this->real << " + " << this->imag << "i" << std::endl;
        }
};

ComplexNumber operator+(ComplexNumber a, ComplexNumber b)
{
    return ComplexNumber(a.real + b.real, a.imag + b.imag);
}

ComplexNumber operator-(ComplexNumber a, ComplexNumber b) {
    return ComplexNumber(a.real - b.real, a.imag - b.imag);
}

ComplexNumber operator*(ComplexNumber a, ComplexNumber b)
{
    /* FOIL Method
    double real = (a.real * b.real);
    double imag = (a.real * b.imag) + (a.imag * b.real);
    double imagSquare = (a.imag * b.imag);
    */
    
    // (ac - bd) + (ad + bc)i
    return ComplexNumber((a.real * b.real) - (a.imag * b.imag), (a.real * b.imag) + (a.imag * b.real));
}