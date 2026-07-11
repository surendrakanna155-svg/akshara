"""Knowledge Layer — Phase 4: expanded certified template library (content-only).

These are ADDITIONAL solver-verified, deterministic question families authored in the KNOWLEDGE
LAYER and registered into the engine's template REGISTRY by a tiny loader at the end of
qpgen/templates.py. They are CONTENT, not engine logic — the frozen engine's matching
(find_template), instantiation, validation and selection are untouched; only the certified-family
data set grows (exactly what qpgen/templates.py's own docstring sanctions: "the set can grow
without engine changes").

Every family here:
  * is SOLVER-VERIFIED — the answer is COMPUTED from the parameters, never asserted;
  * is copyright-safe / fabrication-free — universal formulas, SI units, named laws only;
  * binds conservatively via conjunctive keyword groups chosen to match real CBSE/AP/TS/NEET/JEE
    concepts WITHOUT colliding with the engine's test fixtures or the "stays a spec" concepts;
  * yields well-formed MCQs automatically (the engine's _mcq_options pads to 4 distinct options).

build_families() receives the engine's own helpers by argument (no import of qpgen here), so
there is zero circular dependency: the engine passes its primitives in when it loads us.
"""
from __future__ import annotations


def build_families(Template, num_family, mcq_options, p, n, QT):
    """Return the Phase-4 certified families, built with the engine's own primitives."""
    NUM = (QT.NUMERICAL,)
    NUM_MCQ = (QT.NUMERICAL, QT.MCQ)

    # ── Physics ───────────────────────────────────────────────────────────────────────
    def g_parallel_resistance(cc, s):
        a = p(cc, s, "a", 2, 20); b = p(cc, s, "b", 2, 20)
        rp = (a * b) / (a + b)                                     # solver: 1/Rp = 1/a + 1/b
        return {"stem": f"Two resistors of {a} Ω and {b} Ω are connected in parallel. Calculate their "
                        f"equivalent resistance.",
                "answer": f"{n(rp)} Ω", "solution": f"1/Rp = 1/{a} + 1/{b} ⇒ Rp = ({a}×{b})/({a}+{b}) = {n(rp)} Ω.",
                "distractors": [f"{n(a+b)} Ω", f"{n(a*b)} Ω", f"{n((a+b)/2)} Ω"]}

    def g_displacement(cc, s):
        u = p(cc, s, "u", 0, 15); a = p(cc, s, "a", 2, 10); t = p(cc, s, "t", 2, 8)
        disp = u * t + 0.5 * a * t * t                            # solver: s = ut + ½at²
        return {"stem": f"A body starts with a velocity of {u} m/s and accelerates uniformly at {a} m/s² "
                        f"for {t} s. Calculate the distance it travels.",
                "answer": f"{n(disp)} m", "solution": f"s = ut + ½at² = {u}×{t} + ½×{a}×{t}² = {n(disp)} m.",
                "distractors": [f"{n(u*t)} m", f"{n(0.5*a*t*t)} m", f"{n(u+a*t)} m"]}

    def g_acceleration(cc, s):
        u = p(cc, s, "u", 0, 10); t = p(cc, s, "t", 2, 10); a = p(cc, s, "a", 2, 12)
        v = u + a * t
        return {"stem": f"The velocity of a body changes from {u} m/s to {v} m/s in {t} s. Calculate its "
                        f"acceleration.",
                "answer": f"{n(a)} m/s²", "solution": f"a = (v − u)/t = ({v} − {u})/{t} = {n(a)} m/s².",
                "distractors": [f"{n((v+u)/t)} m/s²", f"{n(v/t)} m/s²", f"{n((v-u)*t)} m/s²"]}

    def g_impulse(cc, s):
        f = p(cc, s, "f", 2, 40); t = p(cc, s, "t", 2, 12); j = f * t
        return {"stem": f"A constant force of {f} N acts on a body for {t} s. Calculate the impulse imparted.",
                "answer": f"{n(j)} N·s", "solution": f"Impulse = F·t = {f} × {t} = {n(j)} N·s.",
                "distractors": [f"{n(f+t)} N·s", f"{n(f)} N·s", f"{n(f*t/2 if (f*t)%2==0 else f*t+1)} N·s"]}

    def g_pressure_liquid(cc, s):
        h = p(cc, s, "h", 2, 20); rho = p(cc, s, "d", 1, 13) * 100; g = 10
        pr = h * rho * g                                          # solver: P = hρg
        return {"stem": f"Calculate the pressure exerted by a liquid column of height {h} m and density "
                        f"{rho} kg/m³ (take g = 10 m/s²).",
                "answer": f"{n(pr)} Pa", "solution": f"P = hρg = {h} × {rho} × 10 = {n(pr)} Pa.",
                "distractors": [f"{n(h*rho)} Pa", f"{n(rho*g)} Pa", f"{n(h*g)} Pa"]}

    def g_efficiency(cc, s):
        inp = p(cc, s, "i", 5, 20) * 10; frac = p(cc, s, "f", 2, 9)
        out = inp * frac // 10                                    # ensures out < inp, integer
        eff = out * 100 / inp
        return {"stem": f"A machine takes in {inp} J of energy and does {out} J of useful work. Calculate "
                        f"its efficiency.",
                "answer": f"{n(eff)} %", "solution": f"η = (useful output ÷ input) × 100 = ({out}/{inp})×100 = {n(eff)} %.",
                "distractors": [f"{n(inp*100/out)} %", f"{n(out/inp)} %", f"{n(inp-out)} %"]}

    def g_latent_heat(cc, s):
        m = p(cc, s, "m", 2, 20); L = p(cc, s, "L", 20, 400) * 10; q = m * L
        return {"stem": f"Calculate the heat required to change the state of {m} kg of a substance whose "
                        f"specific latent heat is {L} J/kg.",
                "answer": f"{n(q)} J", "solution": f"Q = mL = {m} × {L} = {n(q)} J.",
                "distractors": [f"{n(m+L)} J", f"{n(L)} J", f"{n(m)} J"]}

    def g_lens_power(cc, s):
        fcm = p(cc, s, "f", 1, 10) * 10                          # focal length 10..100 cm
        power = 100 / fcm                                         # solver: P = 1/f(m) = 100/f(cm) dioptre
        return {"stem": f"A converging lens has a focal length of {fcm} cm. Calculate its power in dioptres.",
                "answer": f"{n(power)} D", "solution": f"P = 1/f(m) = 100/{fcm} = {n(power)} D.",
                "distractors": [f"{n(fcm)} D", f"{n(fcm/100)} D", f"{n(power+1)} D"]}

    def g_refractive_index(cc, s):
        app = p(cc, s, "a", 2, 8); factor = p(cc, s, "k", 2, 4); real = app * factor
        ri = real / app                                          # solver: n = real depth / apparent depth
        return {"stem": f"An object at the bottom of a tank of real depth {real} cm appears to be at a "
                        f"depth of {app} cm. Calculate the refractive index of the liquid.",
                "answer": f"{n(ri)}", "solution": f"n = real depth ÷ apparent depth = {real}/{app} = {n(ri)}.",
                "distractors": [f"{n(app/real)}", f"{n(real*app)}", f"{n(real-app)}"]}

    def g_frequency_period(cc, s):
        f_hz = p(cc, s, "f", 2, 20); period = 1 / f_hz
        return {"stem": f"A wave has a frequency of {f_hz} Hz. Calculate its time period.",
                "answer": f"{n(period)} s", "solution": f"T = 1/f = 1/{f_hz} = {n(period)} s.",
                "distractors": [f"{n(f_hz)} s", f"{n(2/f_hz)} s", f"{n(f_hz/2)} s"]}

    # ── Chemistry ─────────────────────────────────────────────────────────────────────
    def g_molality(cc, s):
        moles = p(cc, s, "n", 2, 12); kg = p(cc, s, "k", 1, 5); mol = moles / kg
        return {"stem": f"A solution contains {moles} mol of solute dissolved in {kg} kg of solvent. "
                        f"Calculate its molality.",
                "answer": f"{n(mol)} mol/kg", "solution": f"molality = moles of solute ÷ kg of solvent = {moles}/{kg} = {n(mol)} mol/kg.",
                "distractors": [f"{n(moles*kg)} mol/kg", f"{n(kg/moles)} mol/kg", f"{n(moles+kg)} mol/kg"]}

    def g_mass_percent(cc, s):
        sol = p(cc, s, "s", 2, 20); total = sol + p(cc, s, "w", 2, 30); pct = sol * 100 / total
        return {"stem": f"A solution is prepared by dissolving {sol} g of solute in enough solvent to make "
                        f"{total} g of solution. Calculate the mass percentage of the solute.",
                "answer": f"{n(pct)} %", "solution": f"mass % = (mass of solute ÷ mass of solution) × 100 = ({sol}/{total})×100 = {n(pct)} %.",
                "distractors": [f"{n(total*100/sol)} %", f"{n(sol/total)} %", f"{n(sol+total)} %"]}

    def g_boyle(cc, s):
        p1 = p(cc, s, "p", 2, 20); v2 = p(cc, s, "v", 2, 10); k = p(cc, s, "k", 2, 5)
        v1 = v2 * k; p2 = p1 * v1 / v2                           # solver: P1V1 = P2V2
        return {"stem": f"A gas at a pressure of {p1} atm occupies {v1} L. At constant temperature it is "
                        f"compressed to {v2} L. Calculate the new pressure.",
                "answer": f"{n(p2)} atm", "solution": f"By Boyle's law, P₂ = P₁V₁/V₂ = ({p1}×{v1})/{v2} = {n(p2)} atm.",
                "distractors": [f"{n(p1*v2/v1)} atm", f"{n(p1)} atm", f"{n(p1*v1*v2)} atm"]}

    def g_charles(cc, s):
        v1 = p(cc, s, "v", 2, 20); t1 = p(cc, s, "t", 2, 6) * 100; k = p(cc, s, "k", 2, 4)
        t2 = t1 * k; v2 = v1 * t2 / t1                           # solver: V1/T1 = V2/T2
        return {"stem": f"A gas occupies {v1} L at {t1} K. At constant pressure its temperature is raised "
                        f"to {t2} K. Calculate the new volume.",
                "answer": f"{n(v2)} L", "solution": f"By Charles's law, V₂ = V₁T₂/T₁ = ({v1}×{t2})/{t1} = {n(v2)} L.",
                "distractors": [f"{n(v1*t1/t2)} L", f"{n(v1)} L", f"{n(v1+k)} L"]}

    def g_half_life(cc, s):
        base = p(cc, s, "b", 2, 10); half = p(cc, s, "h", 1, 5); n0 = base * (2 ** half)
        remaining = n0 / (2 ** half)                             # solver: N = N₀/2^(t/t½)
        return {"stem": f"A radioactive sample of initial mass {n0} g has undergone {half} half-lives. "
                        f"Calculate the mass of the sample that remains.",
                "answer": f"{n(remaining)} g", "solution": f"N = N₀ / 2^(number of half-lives) = {n0} / 2^{half} = {n(remaining)} g.",
                "distractors": [f"{n(n0/half)} g", f"{n(n0*2**half)} g", f"{n(n0-half)} g"]}

    def g_percent_yield(cc, s):
        theo = p(cc, s, "t", 5, 20) * 2; actual = p(cc, s, "a", 2, 9) * (theo // 10 or 1)
        actual = min(actual, theo); yld = actual * 100 / theo
        return {"stem": f"A reaction has a theoretical yield of {theo} g but produces only {actual} g of "
                        f"product. Calculate the percentage yield.",
                "answer": f"{n(yld)} %", "solution": f"% yield = (actual ÷ theoretical) × 100 = ({actual}/{theo})×100 = {n(yld)} %.",
                "distractors": [f"{n(theo*100/actual)} %", f"{n(actual/theo)} %", f"{n(theo-actual)} %"]}

    def g_normality(cc, s):
        molarity = p(cc, s, "m", 1, 6); nfactor = p(cc, s, "f", 1, 4); normality = molarity * nfactor
        return {"stem": f"A solution has a molarity of {molarity} M and the solute has an n-factor of "
                        f"{nfactor}. Calculate its normality.",
                "answer": f"{n(normality)} N", "solution": f"Normality = Molarity × n-factor = {molarity} × {nfactor} = {n(normality)} N.",
                "distractors": [f"{n(molarity/nfactor if nfactor else molarity)} N", f"{n(molarity+nfactor)} N", f"{n(molarity)} N"]}

    # ── Mathematics ───────────────────────────────────────────────────────────────────
    _TRIPLES = ((3, 4, 5), (5, 12, 13), (8, 15, 17), (6, 8, 10), (9, 12, 15), (7, 24, 25))

    def g_distance_points(cc, s):
        dx, dy, hyp = _TRIPLES[p(cc, s, "t", 0, len(_TRIPLES) - 1)]
        x1 = p(cc, s, "x", 0, 5); y1 = p(cc, s, "y", 0, 5)
        x2, y2 = x1 + dx, y1 + dy
        return {"stem": f"Find the distance between the points ({x1}, {y1}) and ({x2}, {y2}).",
                "answer": f"{n(hyp)} units", "solution": f"d = √[({x2}−{x1})² + ({y2}−{y1})²] = √[{dx}² + {dy}²] = {n(hyp)} units.",
                "distractors": [f"{n(dx+dy)} units", f"{n(abs(dx-dy))} units", f"{n(dx*dy)} units"]}

    def g_slope(cc, s):
        x1 = p(cc, s, "x", 0, 4); y1 = p(cc, s, "y", 0, 4)
        run = p(cc, s, "r", 1, 5); m = p(cc, s, "m", 1, 6)
        x2, y2 = x1 + run, y1 + run * m                          # slope = m (integer)
        return {"stem": f"Find the slope of the line passing through ({x1}, {y1}) and ({x2}, {y2}).",
                "answer": f"{n(m)}", "solution": f"slope = (y₂−y₁)/(x₂−x₁) = ({y2}−{y1})/({x2}−{x1}) = {n(m)}.",
                "distractors": [f"{n((x2-x1)/(y2-y1) if y2!=y1 else 0)}", f"{n(m+1)}", f"{n(y2+y1)}"]}

    def g_midpoint(cc, s):
        x1 = p(cc, s, "x", 0, 10) * 2; y1 = p(cc, s, "y", 0, 10) * 2
        x2 = p(cc, s, "u", 0, 10) * 2; y2 = p(cc, s, "v", 0, 10) * 2
        mx, my = (x1 + x2) // 2, (y1 + y2) // 2
        return {"stem": f"Find the midpoint of the line segment joining ({x1}, {y1}) and ({x2}, {y2}).",
                "answer": f"({mx}, {my})", "solution": f"Midpoint = ((x₁+x₂)/2, (y₁+y₂)/2) = ({mx}, {my}).",
                "distractors": []}

    def g_triangle_area(cc, s):
        b = p(cc, s, "b", 2, 20); h = p(cc, s, "h", 2, 20); area = 0.5 * b * h
        return {"stem": f"Find the area of a triangle with base {b} cm and height {h} cm.",
                "answer": f"{n(area)} cm²", "solution": f"Area = ½ × base × height = ½ × {b} × {h} = {n(area)} cm².",
                "distractors": [f"{n(b*h)} cm²", f"{n(b+h)} cm²", f"{n(0.5*(b+h))} cm²"]}

    def g_cube_surface(cc, s):
        a = p(cc, s, "a", 2, 20); sa = 6 * a * a
        return {"stem": f"Find the total surface area of a cube of edge {a} cm.",
                "answer": f"{n(sa)} cm²", "solution": f"Surface area of a cube = 6a² = 6 × {a}² = {n(sa)} cm².",
                "distractors": [f"{n(a*a)} cm²", f"{n(a*a*a)} cm²", f"{n(4*a*a)} cm²"]}

    def g_compound_interest(cc, s):
        pr = p(cc, s, "p", 1, 20) * 100; r = p(cc, s, "r", 1, 5) * 5; t = 2
        amount = pr * (1 + r / 100) ** t; ci = amount - pr       # solver: CI = P(1+r/100)^t − P
        return {"stem": f"Find the compound interest on ₹{pr} at {r}% per annum for {t} years, compounded annually.",
                "answer": f"₹{n(ci)}", "solution": f"A = P(1+r/100)ᵗ = {pr}(1+{r}/100)² = {n(amount)}; CI = A − P = {n(ci)}.",
                "distractors": [f"₹{n(pr*r*t/100)}", f"₹{n(amount)}", f"₹{n(pr*r/100)}"]}

    def g_mean(cc, s):
        count = p(cc, s, "c", 3, 8); avg = p(cc, s, "a", 5, 40); total = count * avg
        return {"stem": f"The sum of {count} observations is {total}. Calculate their arithmetic mean.",
                "answer": f"{n(avg)}", "solution": f"Mean = sum of observations ÷ number of observations = {total}/{count} = {n(avg)}.",
                "distractors": [f"{n(total*count)}", f"{n(total-count)}", f"{n(total+count)}"]}

    def g_hcf(cc, s):
        g = p(cc, s, "g", 2, 12); a = g * p(cc, s, "a", 2, 9); b = g * p(cc, s, "b", 2, 9)
        import math
        hcf = math.gcd(a, b)
        return {"stem": f"Find the highest common factor (HCF) of {a} and {b}.",
                "answer": f"{n(hcf)}", "solution": f"The HCF of {a} and {b} is {n(hcf)} (the largest integer dividing both).",
                "distractors": [f"{n(a*b)}", f"{n(a+b)}", f"{n(a*b//hcf)}"]}

    def g_gp_sum(cc, s):
        a = p(cc, s, "a", 1, 6); r = p(cc, s, "r", 2, 4); nn = p(cc, s, "n", 2, 6)
        total = a * (r ** nn - 1) // (r - 1)                     # solver: Sₙ = a(rⁿ−1)/(r−1)
        return {"stem": f"Find the sum of the first {nn} terms of a geometric progression whose first term "
                        f"is {a} and whose common ratio is {r}.",
                "answer": f"{n(total)}", "solution": f"Sₙ = a(rⁿ−1)/(r−1) = {a}({r}^{nn}−1)/({r}−1) = {n(total)}.",
                "distractors": [f"{n(a*r**nn)}", f"{n(a*nn)}", f"{n(a*(r**nn)//r)}"]}

    # ── Biology ───────────────────────────────────────────────────────────────────────
    def g_gametes(cc, s):
        k = p(cc, s, "k", 1, 6); count = 2 ** k
        return {"stem": f"An organism is heterozygous for {k} independently assorting gene pairs. Calculate "
                        f"the number of genetically different gametes it can produce.",
                "answer": f"{n(count)}", "solution": f"Number of gamete types = 2ⁿ where n = {k} ⇒ 2^{k} = {n(count)}.",
                "distractors": [f"{n(2*k)}", f"{n(k*k)}", f"{n(count*2)}"]}

    def g_resp_quotient(cc, s):
        o2 = p(cc, s, "o", 2, 10); k = p(cc, s, "k", 1, 3); co2 = o2 * k
        rq = co2 / o2                                            # solver: RQ = CO₂ released / O₂ consumed
        return {"stem": f"During respiration an organism releases {co2} mL of CO₂ and consumes {o2} mL of "
                        f"O₂. Calculate the respiratory quotient (RQ).",
                "answer": f"{n(rq)}", "solution": f"RQ = volume of CO₂ released ÷ volume of O₂ consumed = {co2}/{o2} = {n(rq)}.",
                "distractors": [f"{n(o2/co2)}", f"{n(co2*o2)}", f"{n(co2-o2)}"]}

    # ════════════════════════════════════════════════════════════════════════════════
    # Phase 7 batch — families targeting the corpus's actual HIGH-FREQUENCY computable
    # concepts that the Phase-4 library missed (measured on the live KIE: Equilibrium 317,
    # Probability 102, Integers 96, Magnetic Flux 76, Circles 56, gravitational force 48,
    # Perimeter/Triangle/Parallelogram/Median). Bindings use the concepts' ACTUAL tagged
    # titles/subjects (a generic single-word group is fine here: the instance is always a
    # solver-verified, in-syllabus, original question about that topic). All clean-number.
    # ════════════════════════════════════════════════════════════════════════════════
    def g_gravitational_force(cc, s):
        m = p(cc, s, "m", 2, 50); g = 10; w = m * g              # solver: F = m·g near Earth
        return {"stem": f"A body of mass {m} kg is near the Earth's surface (take g = 10 m/s²). "
                        f"Calculate the gravitational force (weight) acting on it.",
                "answer": f"{n(w)} N", "solution": f"F = m·g = {m} × 10 = {n(w)} N.",
                "distractors": [f"{n(m)} N", f"{n(m+g)} N", f"{n(m*9)} N"]}

    def g_magnetic_flux(cc, s):
        b = p(cc, s, "b", 2, 12); a = p(cc, s, "a", 2, 10); phi = b * a   # solver: Φ = B·A (⊥)
        return {"stem": f"A uniform magnetic field of {b} T acts perpendicular to a plane surface of "
                        f"area {a} m². Calculate the magnetic flux through it.",
                "answer": f"{n(phi)} Wb", "solution": f"Φ = B·A = {b} × {a} = {n(phi)} Wb.",
                "distractors": [f"{n(b+a)} Wb", f"{n(b)} Wb", f"{n(a)} Wb"]}

    def g_equilibrium_kc(cc, s):
        a = p(cc, s, "a", 1, 6); k = p(cc, s, "k", 2, 9); b = a * k       # solver: Kc = [B]/[A]
        return {"stem": f"For the reversible reaction A ⇌ B, the equilibrium concentrations are "
                        f"[A] = {a} mol/L and [B] = {b} mol/L. Calculate the equilibrium constant Kc.",
                "answer": f"{n(k)}", "solution": f"Kc = [B]/[A] = {b}/{a} = {n(k)}.",
                "distractors": [f"{n(a/b)}", f"{n(a*b)}", f"{n(a+b)}"]}

    def g_probability(cc, s):
        r = p(cc, s, "r", 2, 9); bl = p(cc, s, "b", 2, 9); tot = r + bl   # solver: P = fav/total
        return {"stem": f"A bag contains {r} red and {bl} blue balls of the same size. One ball is drawn "
                        f"at random. What is the probability that it is red?",
                "answer": f"{r}/{tot}", "solution": f"P(red) = red/total = {r}/{r}+{bl} = {r}/{tot}.",
                "distractors": [f"{bl}/{tot}", f"{r}/{bl}", f"{tot}/{r}"]}

    def g_integer_eval(cc, s):
        a = p(cc, s, "a", 3, 15); b = p(cc, s, "b", 2, 12); v = (-a) * b  # solver: (−a)×b
        return {"stem": f"Evaluate the product of the integers (−{a}) and (+{b}).",
                "answer": f"{n(v)}", "solution": f"(−{a}) × (+{b}) = −({a}×{b}) = {n(v)}.",
                "distractors": [f"{n(a*b)}", f"{n(-(a+b))}", f"{n(a-b)}"]}

    def g_circle_area(cc, s):
        m = p(cc, s, "m", 1, 6); rad = 7 * m; area = (22 * rad * rad) // 7  # solver: πr², π=22/7
        return {"stem": f"A circle has a radius of {rad} cm. Taking π = 22/7, calculate its area.",
                "answer": f"{n(area)} cm²", "solution": f"Area = πr² = (22/7) × {rad}² = {n(area)} cm².",
                "distractors": [f"{n(2*22*rad//7)} cm²", f"{n(area*2)} cm²", f"{n(rad*rad)} cm²"]}

    def g_triangle_area(cc, s):
        base = p(cc, s, "b", 4, 20) * 2; h = p(cc, s, "h", 3, 18); ar = base * h // 2  # ½·b·h
        return {"stem": f"A triangle has a base of {base} cm and a height of {h} cm. Calculate its area.",
                "answer": f"{n(ar)} cm²", "solution": f"Area = ½ × base × height = ½ × {base} × {h} = {n(ar)} cm².",
                "distractors": [f"{n(base*h)} cm²", f"{n(base+h)} cm²", f"{n((base+h)*2)} cm²"]}

    def g_perimeter_rect(cc, s):
        l = p(cc, s, "l", 4, 30); b = p(cc, s, "b", 3, 25); per = 2 * (l + b)   # solver: 2(l+b)
        return {"stem": f"A rectangle has length {l} cm and breadth {b} cm. Calculate its perimeter.",
                "answer": f"{n(per)} cm", "solution": f"Perimeter = 2(l + b) = 2({l} + {b}) = {n(per)} cm.",
                "distractors": [f"{n(l*b)} cm", f"{n(l+b)} cm", f"{n(2*l+b)} cm"]}

    def g_parallelogram_area(cc, s):
        base = p(cc, s, "b", 4, 25); h = p(cc, s, "h", 3, 18); ar = base * h    # solver: b·h
        return {"stem": f"A parallelogram has a base of {base} cm and a corresponding height of {h} cm. "
                        f"Calculate its area.",
                "answer": f"{n(ar)} cm²", "solution": f"Area = base × height = {base} × {h} = {n(ar)} cm².",
                "distractors": [f"{n(base+h)} cm²", f"{n(base*h//2)} cm²", f"{n(2*(base+h))} cm²"]}

    def g_magnetic_force_wire(cc, s):
        b = p(cc, s, "b", 2, 9); i = p(cc, s, "i", 2, 10); l = p(cc, s, "l", 2, 8)
        f = b * i * l                                                # solver: F = B·I·L
        return {"stem": f"A straight wire of length {l} m carries a current of {i} A perpendicular to "
                        f"a uniform magnetic field of {b} T. Calculate the force on the wire.",
                "answer": f"{n(f)} N", "solution": f"F = B·I·L = {b} × {i} × {l} = {n(f)} N.",
                "distractors": [f"{n(b+i+l)} N", f"{n(b*i)} N", f"{n(i*l)} N"]}

    def g_electric_current(cc, s):
        q = p(cc, s, "q", 2, 20) * p(cc, s, "k", 2, 6); t = p(cc, s, "t", 2, 10)
        i = q / t if q % t == 0 else (q // t) or 1
        q = i * t                                                    # keep it integer-clean
        return {"stem": f"A charge of {n(q)} C flows through a conductor in {t} s. Calculate the "
                        f"electric current.",
                "answer": f"{n(i)} A", "solution": f"I = Q/t = {n(q)}/{t} = {n(i)} A.",
                "distractors": [f"{n(q)} A", f"{n(q*t)} A", f"{n(t)} A"]}

    def g_friction_force(cc, s):
        mu10 = p(cc, s, "u", 2, 8); n_norm = p(cc, s, "N", 10, 90)
        mu = mu10 / 10.0; fr = mu * n_norm                          # solver: f = μN
        return {"stem": f"A block experiences a normal reaction of {n_norm} N on a surface whose "
                        f"coefficient of friction is {mu}. Calculate the force of friction.",
                "answer": f"{n(fr)} N", "solution": f"f = μN = {mu} × {n_norm} = {n(fr)} N.",
                "distractors": [f"{n(n_norm)} N", f"{n(mu)} N", f"{n(n_norm/max(mu,0.1))} N"]}

    def g_cuboid_volume_generic(cc, s):
        a = p(cc, s, "a", 2, 12); b = p(cc, s, "b", 2, 12); c = p(cc, s, "c", 2, 12)
        v = a * b * c                                                # solver: V = l·b·h
        return {"stem": f"A cuboid has dimensions {a} cm × {b} cm × {c} cm. Calculate its volume.",
                "answer": f"{n(v)} cm³", "solution": f"V = l × b × h = {a} × {b} × {c} = {n(v)} cm³.",
                "distractors": [f"{n(a+b+c)} cm³", f"{n(2*(a*b+b*c+a*c))} cm³", f"{n(a*b)} cm³"]}

    def g_median_odd(cc, s):
        a = p(cc, s, "a", 1, 9); step = p(cc, s, "d", 1, 6)
        vals = [a, a + step, a + 2 * step, a + 3 * step, a + 4 * step]      # 5 sorted values
        med = vals[2]                                                        # solver: middle term
        return {"stem": f"Find the median of the data set: {', '.join(str(v) for v in vals)}.",
                "answer": f"{n(med)}", "solution": f"Odd count (5): median = 3rd value = {n(med)}.",
                "distractors": [f"{n(sum(vals)//5)}", f"{n(vals[0])}", f"{n(vals[-1])}"]}

    return [
        # Physics
        num_family("phy_parallel_resistance", "Physics",
                   (("resistors in parallel",), ("parallel combination",), ("parallel", "resistance")), g_parallel_resistance),
        num_family("phy_displacement_motion", "Physics",
                   (("distance travelled", "acceleration"), ("second equation of motion",),
                    ("displacement", "uniformly accelerated")), g_displacement),
        num_family("phy_acceleration", "Physics",
                   (("rate of change of velocity",), ("acceleration", "initial velocity")), g_acceleration),
        num_family("phy_impulse", "Physics", (("impulse",),), g_impulse),
        num_family("phy_pressure_liquid", "Physics",
                   (("pressure", "liquid column"), ("hydrostatic pressure",), ("pressure at a depth",)), g_pressure_liquid),
        num_family("phy_efficiency", "Physics", (("efficiency",),), g_efficiency),
        num_family("phy_latent_heat", "Physics", (("latent heat",),), g_latent_heat),
        num_family("phy_lens_power", "Physics", (("power of a lens",), ("power", "dioptre")), g_lens_power),
        num_family("phy_refractive_index", "Physics",
                   (("refractive index",), ("apparent depth",), ("snell",)), g_refractive_index),
        num_family("phy_frequency_period", "Physics",
                   (("time period", "frequency"), ("frequency", "hertz")), g_frequency_period),
        # Chemistry
        num_family("chem_molality", "Chemistry", (("molality",),), g_molality),
        num_family("chem_mass_percent", "Chemistry",
                   (("mass percentage",), ("percentage by mass",), ("percent by mass",)), g_mass_percent),
        num_family("chem_boyles_law", "Chemistry", (("boyle",),), g_boyle),
        num_family("chem_charles_law", "Chemistry", (("charles",),), g_charles),
        num_family("chem_half_life", "Chemistry", (("half-life",), ("half life",)), g_half_life),
        num_family("chem_percent_yield", "Chemistry", (("percentage yield",), ("percent yield",)), g_percent_yield),
        num_family("chem_normality", "Chemistry", (("normality",),), g_normality),
        # Mathematics
        num_family("math_distance_points", "Mathematics",
                   (("distance between two points",), ("distance formula",)), g_distance_points),
        num_family("math_slope", "Mathematics",
                   (("slope of a line",), ("slope", "two points"), ("gradient of a line",)), g_slope),
        num_family("math_midpoint", "Mathematics", (("midpoint",), ("mid-point",)), g_midpoint, NUM),
        num_family("math_triangle_area", "Mathematics",
                   (("area of a triangle",), ("area", "triangle")), g_triangle_area),
        num_family("math_cube_surface_area", "Mathematics",
                   (("surface area of a cube",), ("surface area", "cube")), g_cube_surface),
        num_family("math_compound_interest", "Mathematics", (("compound interest",),), g_compound_interest),
        num_family("math_arithmetic_mean", "Mathematics",
                   (("arithmetic mean",), ("mean of", "observation")), g_mean),
        num_family("math_hcf", "Mathematics",
                   (("hcf",), ("highest common factor",), ("greatest common divisor",)), g_hcf),
        num_family("math_gp_sum", "Mathematics",
                   (("sum of a geometric",), ("sum of n terms of a gp",), ("sum of gp",)), g_gp_sum),
        # Biology
        num_family("bio_gamete_types", "Biology",
                   (("number of gametes",), ("gamete", "heterozygous"), ("independently assorting",)), g_gametes),
        num_family("bio_respiratory_quotient", "Biology",
                   (("respiratory quotient",), ("rq value",)), g_resp_quotient),
        # ── Phase 7 batch: high-frequency computable concepts (measured on live KIE) ──
        num_family("phy_gravitational_force", "Physics",
                   (("gravitational force",), ("law of gravitation",), ("force of gravity",)),
                   g_gravitational_force),
        num_family("phy_magnetic_flux", "Physics",
                   (("magnetic flux",), ("flux", "magnetic")), g_magnetic_flux),
        num_family("chem_equilibrium_kc", "Chemistry",
                   (("equilibrium",),), g_equilibrium_kc),
        num_family("math_probability", "Mathematics",
                   (("probability",),), g_probability),
        num_family("math_integer_ops", "Mathematics",
                   (("integer",),), g_integer_eval),
        num_family("math_circle_measure", "Mathematics",
                   (("circle",),), g_circle_area),
        num_family("math_triangle_measure", "Mathematics",
                   (("triangle",),), g_triangle_area),
        num_family("math_perimeter_rect", "Mathematics",
                   (("perimeter",),), g_perimeter_rect),
        num_family("math_parallelogram_area", "Mathematics",
                   (("parallelogram",),), g_parallelogram_area),
        num_family("math_median_odd", "Mathematics",
                   (("median",),), g_median_odd),
        # ── Phase 3 (Content Density) batch: remaining clean computable concepts ──
        num_family("phy_magnetic_force_wire", "Physics",
                   (("magnetic force",), ("force", "magnetic field"), ("force on a current",)),
                   g_magnetic_force_wire),
        num_family("phy_electric_current", "Physics",
                   (("electric current",), ("current", "charge", "time")), g_electric_current),
        num_family("phy_friction_force", "Physics",
                   (("force of friction",), ("frictional force",), ("coefficient of friction",)),
                   g_friction_force),
        num_family("math_cuboid_volume_generic", "Mathematics",
                   (("volume",), ("volumes",)), g_cuboid_volume_generic),
    ]
