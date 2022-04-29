y = 7

z = y * 5 + 6 

q1(a, s, b) = (s - b)/2*a

function q(a, b ,c)
    s = sqrt(b^2 - 4*a*c)
    q1(a, s, b), q1(a, -s, b)
end
