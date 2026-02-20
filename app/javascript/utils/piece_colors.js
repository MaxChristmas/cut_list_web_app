export const COLORS = [
  "#7DD3FC", "#6EE7B7", "#FDBA74", "#C4B5FD",
  "#FCA5A5", "#5EEAD4", "#FDE047", "#F9A8D4",
  "#A5B4FC", "#BEF264",
]

export function normalizeKey(w, h) {
  return `${Math.min(w, h)}×${Math.max(w, h)}`
}
