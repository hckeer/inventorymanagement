from setuptools import setup, find_packages

setup(
    name="lightbenders_warehouse",
    version="0.1.0",
    description="Lightbenders warehouse containers, equipment assemblies, and pilot seed data for ERPNext v16",
    author="Lightbenders",
    author_email="ops@lightbenders.com",
    packages=find_packages(),
    zip_safe=False,
    include_package_data=True,
    install_requires=[],
)
