from pypdf import PdfReader
import sys

def extract_text(pdf_path):
    try:
        reader = PdfReader(pdf_path)
        text = ""
        for page in reader.pages:
            text += page.extract_text() + "\n"
        print(text)
    except Exception as e:
        print(f"Error reading PDF: {e}")

if __name__ == "__main__":
    extract_text("/Users/nellertcai/Desktop/02-项目文件夹/sora2 Book/english_latex_book/684_685191_AUE_ST_EN.pdf")
