"""
Sanity checker para la Proposicion 5.4 (reduccion de constraints via Tucker).
Toma (R1,R2,R3,C,D,H) y calcula el ratio real, para que un error como el
13.9x/3.42x de una version anterior del paper no pueda volver a colarse sin que
un script lo marque primero.
"""


def constraint_counts(R1, R2, R3, C, D, H):
    compressed = R1 * R2 * R3 + R1 * C + R2 * D + R3 * H
    uncompressed = C * D * H
    return compressed, uncompressed


def report(R1, R2, R3, C, D, H):
    compressed, uncompressed = constraint_counts(R1, R2, R3, C, D, H)
    ratio = uncompressed / compressed
    reduction_pct = (1 - compressed / uncompressed) * 100
    print(f"(R1,R2,R3)=({R1},{R2},{R3})  (C,D,H)=({C},{D},{H})")
    print(f"  compressed   = R1*R2*R3 + R1*C + R2*D + R3*H = {compressed}")
    print(f"  uncompressed = C*D*H = {uncompressed}")
    print(f"  ratio real = {ratio:.4f}x   reduccion = {reduction_pct:.1f}%")
    print()


if __name__ == "__main__":
    print("=== Sanity check: Proposicion 5.4 ===")
    print()
    print("Ejemplo del paper (version corregida):")
    report(4, 3, 3, 20, 5, 5)

    print("Para probar tus propios parametros, editar los valores de abajo:")
    print("(dejando el ejemplo tal cual como plantilla)")
    # report(R1, R2, R3, C, D, H)  # <- copiar y editar esta linea
