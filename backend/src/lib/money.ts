/** Money is integer baisa everywhere (1 OMR = 1000 baisa). */
export const BAISA_PER_OMR = 1000;

export function omr(baisa: number): string {
  return `OMR ${(baisa / BAISA_PER_OMR).toFixed(3).replace(/\.?0+$/, "")}`;
}
