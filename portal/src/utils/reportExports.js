import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import * as XLSX from 'xlsx';

export const downloadBlob = (blob, filename) => {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.style.display = 'none';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
};

export const exportRowsToPdf = async ({ title, filename, columns, rows }) => {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: 'a4' });
  const pageWidth = doc.internal.pageSize.getWidth();
  const today = new Date().toLocaleString();

  // Header bar
  doc.setFillColor(15, 82, 186);
  doc.rect(0, 0, pageWidth, 36, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text('Sanlam Chronic Care', 30, 23);
  doc.setFontSize(11);
  doc.setFont('helvetica', 'normal');
  doc.text(title, pageWidth / 2, 23, { align: 'center' });
  doc.setFontSize(9);
  doc.text(`Generated: ${today}`, pageWidth - 30, 23, { align: 'right' });

  // Table
  autoTable(doc, {
    head: [columns.map((c) => c.label)],
    body: rows.map((row) => columns.map((c) => {
      const v = row[c.key];
      if (Array.isArray(v)) return v.join(', ');
      if (v === null || v === undefined) return '—';
      return String(v);
    })),
    startY: 48,
    styles: { fontSize: 8, cellPadding: 4 },
    headStyles: { fillColor: [15, 82, 186], textColor: 255, fontStyle: 'bold', fontSize: 8 },
    alternateRowStyles: { fillColor: [248, 250, 252] },
    margin: { left: 20, right: 20 },
    didDrawPage: (data) => {
      // Footer on each page
      const pageCount = doc.internal.getNumberOfPages();
      doc.setFontSize(8);
      doc.setTextColor(148, 163, 184);
      doc.text(
        `Page ${data.pageNumber} of ${pageCount}  |  Sanlam Chronic Care — Confidential`,
        pageWidth / 2,
        doc.internal.pageSize.getHeight() - 10,
        { align: 'center' }
      );
    },
  });

  doc.save(filename);
};

export const exportRowsToXlsx = async ({ sheetName, rows, filename, columns }) => {
  let exportData = rows;
  if (columns) {
    exportData = rows.map((row) => {
      const obj = {};
      columns.forEach((c) => {
        const v = row[c.key];
        obj[c.label] = Array.isArray(v) ? v.join(', ') : (v ?? '');
      });
      return obj;
    });
  }
  const worksheet = XLSX.utils.json_to_sheet(exportData);
  // Bold header row
  const range = XLSX.utils.decode_range(worksheet['!ref']);
  for (let C = range.s.c; C <= range.e.c; C++) {
    const addr = XLSX.utils.encode_cell({ r: 0, c: C });
    if (worksheet[addr]) worksheet[addr].s = { font: { bold: true } };
  }
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, sheetName.slice(0, 31));
  XLSX.writeFile(workbook, filename);
};
